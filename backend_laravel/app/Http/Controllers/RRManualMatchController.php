<?php
namespace App\Http\Controllers;

use App\Models\RRManualMatch;
use Illuminate\Http\Request;

class RRManualMatchController extends Controller
{
    // ✅ GET
    public function getByGroup($eventGroupId)
    {
        $matches = RRManualMatch::where('event_group_id', $eventGroupId)
            ->orderBy('round_order')
            ->orderBy('match_order')
            ->get();

        return response()->json([
            "success" => true,
            "data"    => $matches,
        ]);
    }

    // ✅ CREATE BRACKET
    public function createBracket(Request $request)
    {
        $request->validate([
            'event_group_id' => 'required|integer',
            'tournament_id'  => 'required|integer',
            'round_size'     => 'required|integer',
        ]);

        // 🔥 DELETE OLD DATA FIRST (CRITICAL FIX)
        RRManualMatch::where('event_group_id', $request->event_group_id)->delete();

        $roundOrder = 1;
        $matches    = $request->round_size / 2;

        $roundName = match ($request->round_size) {
            16 => "Pre-Quarter",
            8  => "Quarter-Final",
            4  => "Semi-Final",
            2  => "Final",
        };

        for ($i = 1; $i <= $matches; $i++) {
            RRManualMatch::create([
                "tournament_id"  => $request->tournament_id,
                "event_group_id" => $request->event_group_id,
                "round"          => $roundName,
                "round_order"    => $roundOrder,
                "match_order"    => $i,
                "team_a_name"    => "TBD",
                "team_b_name"    => "TBD",
                "status"         => "scheduled",
            ]);
        }

        return response()->json(["success" => true]);
    }

    // ✅ UPDATE MATCH
    public function update(Request $request, $id)
    {
        $match = RRManualMatch::findOrFail($id);

        $match->team_a_id = $request->team_a_id;
        $match->team_b_id = $request->team_b_id;

        $match->team_a_name = $request->team_a_name ?? 'TBD';
        $match->team_b_name = $request->team_b_name ?? 'TBD';

        $match->match_date = $request->match_date;
        $match->match_time = $request->match_time;
        $match->court      = $request->court;

        $match->status         = $request->status ?? 'scheduled';
        $match->winner_team_id = $request->winner_team_id;

        $match->save(); // 🔥 IMPORTANT

        return response()->json([
            'success' => true,
            'data'    => $match,
        ]);
    }

    // ✅ DELETE ALL
    public function deleteAll($eventGroupId)
    {
        try {
            RRManualMatch::where('event_group_id', $eventGroupId)->delete();

            return response()->json([
                'success' => true,
                'message' => 'Deleted successfully',
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'error'   => $e->getMessage(),
            ], 500);
        }
    }
}
