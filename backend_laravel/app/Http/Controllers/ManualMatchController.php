<?php
namespace App\Http\Controllers;

use App\Models\ManualMatch;
use Illuminate\Http\Request;

class ManualMatchController extends Controller
{
    // ➕ CREATE
    public function store(Request $request)
    {
        $match = ManualMatch::create($request->all());

        return response()->json([
            "success" => true,
            "data"    => $match,
        ]);
    }

    // 📥 GET BY GROUP
    public function getByGroup($eventGroupId)
    {
        $matches = ManualMatch::where('event_group_id', $eventGroupId)
            ->orderBy('round_order')
            ->orderBy('match_order')
            ->get();

        return response()->json([
            "success" => true,
            "data"    => $matches,
        ]);
    }

    // ✏️ UPDATE
    public function update(Request $request, $id)
    {
        $match = ManualMatch::findOrFail($id);

        $match->update($request->all());

        return response()->json([
            "success" => true,
            "data"    => $match,
        ]);
    }

    // ❌ DELETE (optional)
    public function delete($id)
    {
        ManualMatch::findOrFail($id)->delete();

        return response()->json(["success" => true]);
    }

    public function createBracket(Request $request)
    {
        try {

            \Log::info("🔥 CREATE BRACKET REQUEST:", $request->all());

            // ✅ SAFE VALIDATION
            $request->validate([
                'event_group_id' => 'required|integer',
                'round_size'     => 'required|integer',
                'tournament_id'  => 'required|integer', // 🔥 IMPORTANT
            ]);

            $eventGroupId = intval($request->event_group_id);
            $roundSize    = intval($request->round_size);
            $tournamentId = intval($request->tournament_id); // ✅ STORE PROPERLY

            // ✅ DEBUG LOG
            \Log::info("EVENT GROUP ID: " . $eventGroupId);
            \Log::info("TOURNAMENT ID: " . $tournamentId);

            // ✅ ADD THIS
            $roundMap = [
                16 => 1,
                8  => 2,
                4  => 3,
                2  => 4,
            ];

            $nextRoundOrder = $roundMap[$roundSize] ?? 1;

            // 🚫 Prevent duplicate
            $exists = ManualMatch::where('event_group_id', $eventGroupId)
                ->where('round_order', $nextRoundOrder)
                ->exists();

            if ($exists) {
                return response()->json([
                    "success" => false,
                    "message" => "This round already exists",
                ], 400);
            }

            $matchesCount = $roundSize / 2;

            $roundName = match ($roundSize) {
                16      => "Pre-Quarter",
                8       => "Quarter-Final",
                4       => "Semi-Final",
                2       => "Final",
                default => "Round"
            };

            for ($i = 1; $i <= $matchesCount; $i++) {

                \Log::info("CREATING MATCH WITH TOURNAMENT ID: " . $tournamentId);

                ManualMatch::create([
                    "tournament_id"  => $tournamentId, // 🔥 FINAL FIX
                    "event_group_id" => $eventGroupId,

                    "team_a_name"    => "TBD",
                    "team_b_name"    => "TBD",

                    "status"         => "scheduled",

                    "round"          => $roundName,
                    "round_order"    => $nextRoundOrder,
                    "match_order"    => $i,
                ]);
            }

            return response()->json([
                "success" => true,
                "message" => "Bracket created",
            ]);

        } catch (\Throwable $e) {

            \Log::error("❌ CREATE BRACKET ERROR: " . $e->getMessage());

            return response()->json([
                "success" => false,
                "message" => $e->getMessage(),
            ], 500);
        }
    }

    public function deleteAll($eventGroupId)
    {
        ManualMatch::where('event_group_id', $eventGroupId)->delete();

        return response()->json([
            "success" => true,
            "message" => "All brackets deleted",
        ]);
    }

}
