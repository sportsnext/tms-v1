<?php
namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\MatchModel;
use App\Models\Result;
use App\Models\Stage;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ResultController extends Controller
{
    public function store(Request $request, $fixtureId)
    {
        $hasScore = $request->has('home_score') && $request->has('away_score');

        $data = $request->validate([
            'home_score' => 'nullable|integer',
            'away_score' => 'nullable|integer',
            'notes'      => 'nullable|string',
            'sets'       => 'nullable|array',
        ]);

        $fixture = MatchModel::findOrFail($fixtureId);

        // 🔥 IF COMPLETED AND NO SCORE SENT → DO NOT TOUCH SCORE
        if (
            strtolower($fixture->status) === 'completed' &&
            ! ($request->has('home_score') && $request->has('away_score'))
        ) {
            return response()->json([
                "success" => true,
                "message" => "Completed without changing score",
            ]);
        }

        \Log::info("🔥 FIXTURE ID:", [$fixtureId]);
        \Log::info("🔥 MATCH FOUND:", [$fixture]);

        // ✅ CORRECT FIELDS (FINAL FIX)
        $homeTeam = $fixture->team_a_id;
        $awayTeam = $fixture->team_b_id;

        \Log::info("🔥 RR HOME: $homeTeam | AWAY: $awayTeam");

        // 🔒 STAGE LOCK
        $stage = Stage::find($fixture->stage_id);
        if ($stage && $stage->status === 'locked') {
            return response()->json([
                "success" => false,
                "message" => "Stage is locked",
            ], 400);
        }

        // ✅ ALLOW ONLY LIVE OR COMPLETED
        // 🔥 ONLY APPLY FOR ROUND ROBIN
        if (
            $fixture->round === "Round Robin" &&
            ! in_array(strtolower($fixture->status), ['live', 'completed'])
        ) {
            return response()->json([
                "success" => false,
                "message" => "Score can only be updated when match is LIVE or COMPLETED",
            ], 400);
        }

        // ✅ AUTO WINNER
        $winnerId   = null;
        $resultType = 'NORMAL';

        $existing = Result::where('fixture_id', $fixtureId)->first();

        if ($hasScore) {
            // ✅ LIVE scoring
            $homeScore = $data['home_score'];
            $awayScore = $data['away_score'];
        } else {
            // ✅ COMPLETED → KEEP OLD SCORE
            $homeScore = $existing?->home_score;
            $awayScore = $existing?->away_score;
        }

        if ($homeScore === null || $awayScore === null) {
            return response()->json([
                "success" => false,
                "message" => "Score must be entered before completing match",
            ], 400);
        }

        if ($homeScore > $awayScore) {
            $winnerId = $homeTeam;
        } elseif ($awayScore > $homeScore) {
            $winnerId = $awayTeam;
        } else {
            if ($request->has('super_tb_winner_id')) {
                $winnerId = $request->super_tb_winner_id;
            } else {
                $resultType = 'DRAW';
            }
        }

        $result = Result::updateOrCreate(
            ['fixture_id' => $fixtureId],
            [
                'home_score'     => $homeScore,
                'away_score'     => $awayScore,
                'winner_team_id' => $winnerId,
                'result_type'    => $resultType,
                'notes'          => $data['notes'] ?? null,
                'sets'           => isset($data['sets']) ? json_encode($data['sets']) : null,
            ]
        );

        $fixture->update([
            'home_score'     => $homeScore,
            'away_score'     => $awayScore,
            'winner_team_id' => $winnerId,
        ]);

        // 🔥 AUDIT LOG
        AuditLog::create([
            'user_id'     => Auth::id(),
            'action'      => $existing ? 'UPDATE_RESULT' : 'CREATE_RESULT',
            'entity_type' => 'fixture',
            'entity_id'   => $fixtureId,
            'old_data'    => $existing ? json_encode($existing) : null,
            'new_data'    => json_encode($result),
        ]);

        // 🔥 IMPORTANT
        StandingController::recalculate($fixture->event_group_id);

        return response()->json([
            "success" => true,
            "data"    => $result,
        ]);
    }

    public function update(Request $request, $fixtureId)
    {
        $hasScore = $request->has('home_score') && $request->has('away_score');

        $result = Result::where('fixture_id', $fixtureId)->firstOrFail();

        $fixture = MatchModel::findOrFail($fixtureId);

        // 🔥 IF COMPLETED AND NO SCORE SENT → DO NOT TOUCH SCORE
        if (
            strtolower($fixture->status) === 'completed' &&
            ! ($request->has('home_score') && $request->has('away_score'))
        ) {
            return response()->json([
                "success" => true,
                "message" => "Completed without changing score",
            ]);
        }

        \Log::info("🔥 FIXTURE ID:", [$fixtureId]);
        \Log::info("🔥 MATCH FOUND:", [$fixture]);

        // 🔒 LOCK
        $stage = Stage::find($fixture->stage_id);
        if ($stage && $stage->status === 'locked') {
            return response()->json([
                "success" => false,
                "message" => "Stage is locked",
            ], 400);
        }

        // ✅ ALLOW ONLY LIVE OR COMPLETED
        // 🔥 ONLY APPLY FOR ROUND ROBIN
        if (
            $fixture->round === "Round Robin" &&
            ! in_array(strtolower($fixture->status), ['live', 'completed'])
        ) {
            return response()->json([
                "success" => false,
                "message" => "Score can only be updated when match is LIVE or COMPLETED",
            ], 400);
        }

        $data = $request->validate([
            'home_score' => 'nullable|integer',
            'away_score' => 'nullable|integer',
            'notes'      => 'nullable|string',
            'sets'       => 'nullable|array',
        ]);

        // ✅ STORE OLD DATA BEFORE UPDATE
        $oldData = json_encode($result);

        // ✅ CORRECT FIELDS
        $homeTeam = $fixture->team_a_id;
        $awayTeam = $fixture->team_b_id;

        // ✅ AUTO WINNER
        $winnerId   = null;
        $resultType = 'NORMAL';

        if ($hasScore) {
            $homeScore = $data['home_score'];
            $awayScore = $data['away_score'];
        } else {
            $homeScore = $result->home_score;
            $awayScore = $result->away_score;
        }

        if ($homeScore === null || $awayScore === null) {
            return response()->json([
                "success" => false,
                "message" => "Score must be entered before completing match",
            ], 400);
        }

        if ($homeScore > $awayScore) {
            $winnerId = $homeTeam;
        } elseif ($awayScore > $homeScore) {
            $winnerId = $awayTeam;
        } else {
            if ($request->has('super_tb_winner_id')) {
                $winnerId = $request->super_tb_winner_id;
            } else {
                $resultType = 'DRAW';
            }
        }

        $result->update([
            'home_score'     => $homeScore,
            'away_score'     => $awayScore,
            'winner_team_id' => $winnerId,
            'result_type'    => $resultType,
            'notes'          => $data['notes'] ?? null,
            'version'        => $result->version + 1,
        ]);

        $fixture->update([
            'home_score'     => $homeScore,
            'away_score'     => $awayScore,
            'winner_team_id' => $winnerId,
        ]);

        // 🔥 AUDIT LOG
        AuditLog::create([
            'user_id'     => Auth::id(),
            'action'      => 'UPDATE_RESULT',
            'entity_type' => 'fixture',
            'entity_id'   => $fixtureId,
            'old_data'    => $oldData,
            'new_data'    => json_encode($result),
        ]);

        StandingController::recalculate($fixture->event_group_id);

        return response()->json([
            "success" => true,
            "data"    => $result,
        ]);
    }
}
