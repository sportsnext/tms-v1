<?php
namespace App\Http\Controllers;

use App\Models\MatchModel;
use Carbon\Carbon;
use Illuminate\Http\Request;

class MatchController extends Controller
{
    public function updateMatch(Request $request, $id)
    {
        $match = MatchModel::findOrFail($id);

        $group  = \App\Models\EventGroup::find($match->event_group_id);
        $format = strtolower($group->format ?? 'knockout');
        $buffer = $format === 'round_robin' ? 30 : 120;

        // ==============================
        // 🔥 ONLY CONFLICT CHECK (SCHEDULED)
        // ==============================
        if (
            $request->match_date &&
            $request->match_time &&
            strtolower($request->status) === 'scheduled'
        ) {

            $newDateTime = Carbon::parse($request->match_date . ' ' . $request->match_time);

            // ===== VENUE CONFLICT =====
            if ($format === 'knockout' && $request->court) {

                $venueConflict = MatchModel::where('court', $request->court)
                    ->where('id', '!=', $match->id)
                    ->get()
                    ->first(function ($m) use ($newDateTime, $buffer) {

                        if (! $m->match_time) {
                            return false;
                        }

                        $existingTime = Carbon::parse($m->match_date . ' ' . $m->match_time);

                        return abs($existingTime->diffInMinutes($newDateTime)) <= $buffer;
                    });

                /*
                if ($venueConflict) {
                    return response()->json([
                        'message' => 'Venue conflict detected',
                        'type'    => 'venue',
                    ], 409);
                }
                */
            }

            // ===== TEAM CONFLICT =====
            if ($format !== 'knockout') {

                $teamA = $request->team_a_id ?? $match->team_a_id;
                $teamB = $request->team_b_id ?? $match->team_b_id;

                $teamConflict = MatchModel::where(function ($q) use ($teamA, $teamB) {
                    if ($teamA) {
                        $q->orWhere('team_a_id', $teamA)
                            ->orWhere('team_b_id', $teamA);
                    }
                    if ($teamB) {
                        $q->orWhere('team_a_id', $teamB)
                            ->orWhere('team_b_id', $teamB);
                    }
                })
                    ->where('id', '!=', $match->id)
                    ->get()
                    ->first(function ($m) use ($newDateTime, $buffer) {

                        if (! $m->match_time) {
                            return false;
                        }

                        $existingTime = Carbon::parse($m->match_date . ' ' . $m->match_time);

                        return abs($existingTime->diffInMinutes($newDateTime)) <= $buffer;
                    });
                
                /*
                if ($teamConflict) {
                    return response()->json([
                        'message' => 'Team conflict detected',
                        'type'    => 'team',
                    ], 409);
                }
                */
            }
        }

        // ==============================
        // ✅ ALWAYS UPDATE (MAIN FIX)
        // ==============================
        \Log::info("STATUS RECEIVED: " . $request->status);

        $match->team_a_id = $request->has('team_a_id')
            ? ($request->team_a_id ? (int) $request->team_a_id : null)
            : $match->team_a_id;

        $match->team_b_id = $request->has('team_b_id')
            ? ($request->team_b_id ? (int) $request->team_b_id : null)
            : $match->team_b_id;

        // 🔥 SYNC TEAM NAMES (CRITICAL FIX)
        if ($request->has('team_a_name')) {
            $match->team_a_name = $request->team_a_name ?: 'BYE';
        }

        if ($request->has('team_b_name')) {
            $match->team_b_name = $request->team_b_name ?: 'BYE';
        }

        // 🔥 FIX BYE HANDLING (CRITICAL)
        if ($match->team_a_id === null) {
            $match->team_a_name = 'BYE';
        }

        if ($match->team_b_id === null) {
            $match->team_b_name = 'BYE';
        }

        // ✅ KEEP REST SAME
        $match->match_date = ! empty($request->match_date) ? $request->match_date : $match->match_date;
        $match->match_time = ! empty($request->match_time) ? $request->match_time : $match->match_time;
        $match->court      = ! empty($request->court) ? $request->court : $match->court;

        if ($request->has('status')) {
            $match->status = strtolower(trim($request->status));
        }

        if ($request->has('winner_team_id')) {
            $match->winner_team_id = $request->winner_team_id
                ? (int) $request->winner_team_id
                : null;

            $match->winner_team_name = $request->winner_team_name ?? null;
        }

        $match->save();
        $match->refresh();


        $tournament = \App\Models\Tournament::with([
            'eventGroups',
            'eventGroups.matches',
        ])->find($match->tournament_id);

        return response()->json([
            'success' => true,
            'data'    => $tournament,
        ]);
    }

    public function deleteMatch($id)
    {
        $match = \App\Models\ManualMatch::findOrFail($id);

        $match->delete(); // 🔥 soft delete

        return response()->json([
            "success" => true,
            "message" => "Deleted successfully",
        ]);
    }
}
