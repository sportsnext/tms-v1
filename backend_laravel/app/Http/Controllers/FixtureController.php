<?php
namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Fixture;
use App\Models\MatchModel;
use App\Models\Team;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

// ⚠️ IMPORTANT (missing in your file)

class FixtureController extends Controller
{
    // ✅ CREATE FIXTURE (FR-1.1, FR-1.2)
    public function store(Request $request)
    {
        $data = $request->validate([
            'tournament_id' => 'required|integer',
            'stage_id'      => 'required|integer',
            'home_team_id'  => 'required|integer',
            'away_team_id'  => 'required|integer',
            'round'         => 'required|integer',
            'match_date'    => 'nullable|date',
            'match_time'    => 'nullable',
            'venue'         => 'nullable|string',
            'status'        => 'nullable|string',
        ]);

        // ❌ SAME TEAM VALIDATION
        if ($data['home_team_id'] == $data['away_team_id']) {
            return response()->json([
                "success" => false,
                "message" => "Same team cannot play against itself",
            ], 400);
        }

        // ✅ TEAM BELONGS TO SAME TOURNAMENT
        $home = Team::where('id', $data['home_team_id'])
            ->where('tournament_id', $data['tournament_id'])
            ->first();

        $away = Team::where('id', $data['away_team_id'])
            ->where('tournament_id', $data['tournament_id'])
            ->first();

        if (! $home || ! $away) {
            return response()->json([
                "success" => false,
                "message" => "Teams must belong to same tournament",
            ], 400);
        }

        // ❌ DUPLICATE FIXTURE (same round)
        $exists = Fixture::where('stage_id', $data['stage_id'])
            ->where('round', $data['round'])
            ->where(function ($q) use ($data) {
                $q->where([
                    ['home_team_id', $data['home_team_id']],
                    ['away_team_id', $data['away_team_id']],
                ])->orWhere([
                    ['home_team_id', $data['away_team_id']],
                    ['away_team_id', $data['home_team_id']],
                ]);
            })
            ->exists();

        if ($exists) {
            return response()->json([
                "success" => false,
                "message" => "Duplicate fixture in same round",
            ], 400);
        }

        // ✅ CREATE
        $fixture = Fixture::create($data);

        AuditLog::create([
            'user_id'     => Auth::id(),
            'action'      => 'CREATE_FIXTURE',
            'entity_type' => 'fixture',
            'entity_id'   => $fixture->id,
            'old_data'    => null,
            'new_data'    => $fixture->toArray(),
        ]);

        return response()->json([
            "success" => true,
            "data"    => $fixture,
        ]);
    }

    // ✅ GET FIXTURES BY STAGE
    public function index($tournamentId, $stageId)
    {
        try {
            $fixtures = MatchModel::where('matches.tournament_id', $tournamentId)
                ->where('matches.event_group_id', $stageId)

                ->leftJoin('results', 'results.fixture_id', '=', 'matches.id')
                ->leftJoin('teams as t1', 't1.id', '=', 'matches.team_a_id')
                ->leftJoin('teams as t2', 't2.id', '=', 'matches.team_b_id')

                ->select(
                    'matches.id',
                    'matches.tournament_id',
                    'matches.event_group_id as stage_id',

                    'matches.team_a_id',
                    'matches.team_b_id',

                    't1.name as team_a_name',
                    't2.name as team_b_name',

                    'matches.round',
                    'matches.match_date',
                    'matches.match_time',
                    'matches.court',
                    'matches.status',

                    DB::raw('COALESCE(results.home_score, 0) as home_score'),
                    DB::raw('COALESCE(results.away_score, 0) as away_score'),

                    'results.winner_team_id'
                )
                ->orderBy('matches.round')
                ->get();

            return response()->json([
                "success" => true,
                "data"    => $fixtures,
            ]);

        } catch (\Exception $e) {
            return response()->json([
                "success" => false,
                "error"   => $e->getMessage(),
            ], 500);
        }
    }

    // ✅ UPDATE (FR-1.3)
    public function update(Request $request, $id)
    {
        $fixture = Fixture::findOrFail($id);

        $old = $fixture->toArray();

        $fixture->update($request->all());

        AuditLog::create([
            'user_id'     => Auth::id(),
            'action'      => 'UPDATE_FIXTURE',
            'entity_type' => 'fixture',
            'entity_id'   => $fixture->id,
            'old_data'    => $old,
            'new_data'    => $fixture->toArray(),
        ]);

        return response()->json([
            "success" => true,
            "data"    => $fixture,
        ]);
    }

    public function generateRoundRobin(Request $request)
    {
        $teams        = $request->teams; // array of team_ids
        $stageId      = $request->stage_id;
        $tournamentId = $request->tournament_id;

        $fixtures = [];

        $round = 1;

        for ($i = 0; $i < count($teams); $i++) {
            for ($j = $i + 1; $j < count($teams); $j++) {

                $fixtures[] = [
                    'tournament_id' => $tournamentId,
                    'stage_id'      => $stageId,
                    'home_team_id'  => $teams[$i],
                    'away_team_id'  => $teams[$j],
                    'round'         => $round++,
                ];
            }
        }

        return response()->json([
            "success" => true,
            "data"    => $fixtures, // 🔥 ONLY PREVIEW
        ]);
    }
}
