<?php
namespace App\Http\Controllers;

use App\Models\Player;
use App\Models\Team;
use App\Models\Tournament;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class TeamController extends Controller
{
    public function store(Request $request, $id)
    {
        $request->validate([
            'sport'       => 'required|string|max:50',
            'type'        => 'required|in:individual,team_event',
            'coach_name'  => 'nullable|string|max:100',
            'name'        => 'nullable|string|max:255',
            'max_players' => 'nullable|integer|min:2|max:50',
        ]);

        DB::beginTransaction();

        try {

            $tournament = Tournament::findOrFail($id);
            $type       = $request->type === 'team_event' ? 'team_event' : 'individual';

            if ($type === 'team_event' && empty($request->name)) {
                return response()->json([
                    'message' => 'Team name is required for team events',
                ], 400);
            }

            // CREATE TEAM
            $team = Team::create([
                'name'          => $request->name ?: 'Player',
                'sport'         => $request->sport,
                'max_players'   => $type === 'individual' ? 2 : $request->max_players,
                'coach_name'    => $request->coach_name,
                'tournament_id' => $tournament->id,
                'type'          => $request->type,
            ]);

            $players = $request->players ?? [];

            // INSERT PLAYERS (ONLY FOR TEAM EVENT)
            if (! empty($players)) {
                foreach ($players as $name) {

                    if (! $name) {
                        continue;
                    }

                    $player = Player::create([
                        'full_name' => $name,
                        'event_id'  => $tournament->event_id,
                        'type'      => $request->type,
                    ]);

                    DB::table('team_players')->insert([
                        'team_id'       => $team->id,
                        'player_id'     => $player->id,
                        'tournament_id' => $tournament->id,
                        'is_playing'    => 0,
                        'created_at'    => now(),
                        'updated_at'    => now(),
                    ]);
                }
            }

            // ✅ AUTO NAME FOR INDIVIDUAL
            if ($type === 'individual' && empty($request->name)) {

                if (! empty($players)) {
                    $team->name = $players[0];
                } else {
                    $team->name = "Player " . $team->id;
                }

                $team->save();
            }

            DB::commit();

            return response()->json([
                'message' => 'Team created successfully',
                'team'    => $team,
            ], 201);

        } catch (\Exception $e) {

            DB::rollBack();

            \Log::error("TEAM STORE ERROR: " . $e->getMessage());

            return response()->json([
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    public function assignPlayers(Request $request, $teamId)
    {
        $request->validate([
            'player_ids'   => 'array',
            'player_ids.*' => 'exists:players,id',
        ]);

        $team       = Team::findOrFail($teamId);
        $tournament = Tournament::withTrashed()->find($team->tournament_id);

        if (! $tournament) {
            return response()->json([
                "message" => "Tournament not found for this team",
            ], 400);
        }

        if ($team->locked || $team->is_published) {
            return response()->json([
                "message" => "Team rosters are locked and cannot be modified",
            ], 403);
        }

        if ($tournament->is_published) {
            return response()->json([
                "message" => "Team rosters are locked after tournament publish",
            ], 403);
        }

        $playerIds = $request->player_ids ?? [];

        if (count($playerIds) == 0) {
            return response()->json([
                "message" => "No players selected",
            ], 400);
        }

        $limit = 2; // 🔥 fixed limit

        if (count($playerIds) > $limit) {
            return response()->json([
                'message' => "Only $limit players allowed",
            ], 400);
        }

        $players = Player::whereIn('id', $playerIds)->get();

        foreach ($players as $player) {

            // Check if player belongs to event
            // if ($player->event_id != $tournament->event_id) {
            //    return response()->json([
            //        'message' => "Player {$player->id} is not registered for this event",
            //    ], 400);
            //}

            // Check if player already in another team
            $existingTeam = DB::table('team_players')
                ->join('teams', 'team_players.team_id', '=', 'teams.id')
                ->where('team_players.player_id', $player->id)
                ->where('teams.tournament_id', $tournament->id)
                ->where('team_players.team_id', '!=', $team->id)
                ->whereNull('team_players.deleted_at')
                ->exists();

            if ($existingTeam) {
                return response()->json([
                    'message' => "Player {$player->id} already belongs to another team in this tournament",
                ], 409);
            }
        }

        // Insert players safely using transaction
        try {

            DB::transaction(function () use ($playerIds, $team, $tournament) {

                foreach (array_slice($playerIds, 0, $team->max_players) as $playerId) {

                    // CHECK if player already exists in another team
                    $existing = DB::table('team_players')
                        ->join('teams', 'teams.id', '=', 'team_players.team_id')
                        ->where('team_players.player_id', $playerId)
                        ->where('team_players.tournament_id', $tournament->id)
                        ->whereNull('team_players.deleted_at')
                        ->where('team_players.team_id', '!=', $team->id)
                        ->select('teams.name')
                        ->first();

                    if ($existing) {
                        return response()->json([
                            "success" => false,
                            "message" => "Player already assigned to another team",
                        ], 409);
                    }
                }

                // Soft delete previous roster
                DB::table('team_players')
                    ->where('team_id', $team->id)
                    ->where('tournament_id', $tournament->id)
                    ->whereNull('deleted_at')
                    ->update([
                        'deleted_at' => now(),
                        'updated_at' => now(),
                    ]);

                // Insert new roster
                foreach (array_slice($playerIds, 0, 2) as $playerId) {

                    $existing = DB::table('team_players')
                        ->where('player_id', $playerId)
                        ->where('tournament_id', $tournament->id)
                        ->first();

                    if ($existing) {

                        DB::table('team_players')
                            ->where('id', $existing->id)
                            ->update([
                                'team_id'    => $team->id,
                                'deleted_at' => null,
                                'is_playing' => 1,
                                'updated_at' => now(),
                            ]);

                    } else {

                        DB::table('team_players')->insert([
                            'team_id'       => $team->id,
                            'player_id'     => $playerId,
                            'tournament_id' => $tournament->id,
                            'is_playing'    => 1,
                            'created_at'    => now(),
                            'updated_at'    => now(),
                        ]);

                    }

                }

            });

        } catch (QueryException $e) {

            if ($e->getCode() == 23000) {
                return response()->json([
                    "success" => false,
                    "message" => "Player already assigned to another team in this tournament",
                ], 409);
            }

            return response()->json([
                "success" => false,
                "message" => "Database error occurred",
            ], 500);

        } catch (\Exception $e) {

            return response()->json([
                "success" => false,
                "message" => $e->getMessage(),
            ], 422);

        }

        // AUTO UPDATE TEAM STATUS
        $currentPlayerCount = DB::table('team_players')
            ->where('team_id', $team->id)
            ->where('tournament_id', $tournament->id)
            ->where('is_playing', 1)
            ->whereNull('deleted_at')
            ->count();

        if ($currentPlayerCount == $team->max_players) {
            $team->status = 'active';
        } else {
            $team->status = 'draft';
        }

        $team->save();

        $team->refresh();

        // 🔥 AUTO UPDATE TEAM NAME FOR INDIVIDUAL
        if ($team->type === 'individual') {

            $players = DB::table('team_players')
                ->join('players', 'players.id', '=', 'team_players.player_id')
                ->where('team_players.team_id', $team->id)
                ->whereNull('team_players.deleted_at')
                ->pluck('players.full_name')
                ->toArray();

            if (count($players) >= 1) {
                $players    = array_slice($players, 0, 2); // take max 2
                $team->name = implode(' & ', $players);
                $team->save();
            }
        }

        $teamPlayers = DB::table('team_players')
            ->where('team_id', $team->id)
            ->whereNull('deleted_at')
            ->pluck('player_id');

        return response()->json([
            "success" => true,
            "message" => "Roster saved successfully",
            "team_id" => $team->id,
            "players" => $playerIds,
        ], 200);
    }

    public function teamPlayers($teamId)
    {
        $team = Team::findOrFail($teamId);

        $players = DB::table('team_players')
            ->join('players', 'players.id', '=', 'team_players.player_id')
            ->where('team_players.team_id', $teamId)
            ->where('team_players.tournament_id', $team->tournament_id)
            ->whereNull('team_players.deleted_at')
            ->select(
                'players.id',
                'players.full_name',
                'team_players.is_playing'
            )
            ->get();

        return response()->json($players);
    }

    public function index($tournamentId)
    {
        $teams = Team::where('tournament_id', $tournamentId)
            ->orderBy('id', 'desc') 
            ->get()
            ->map(function ($team) {

                $player = DB::table('team_players')
                    ->where('team_id', $team->id)
                    ->where('is_playing', 1)
                    ->whereNull('deleted_at')
                    ->pluck('player_id');

                return [
                    'id'            => $team->id,
                    'name'          => $team->name,
                    'sport'         => $team->sport,
                    'max_players'   => $team->type === 'team_event' ? 2 : $team->max_players,
                    'player_ids'    => $player,
                    'status'        => $team->status,
                    'coach_name'    => $team->coach_name,
                    'type'          => $team->type,
                    'tournament_id' => $team->tournament_id,

                    // ✅ CORRECT (NO $tournament VARIABLE NEEDED)
                    'event_id'      => $team->tournament_id ? optional(\App\Models\Tournament::find($team->tournament_id))->event_id : null,
                    'locked'        => (int) $team->locked,
                    'is_published'  => (int) $team->is_published,
                    'is_locked'     => (int) $team->locked,
                ];
            });

        return response()->json($teams);
    }

    public function allTeams()
    {
        $teams = DB::table('teams')
            ->leftJoin('team_players', 'teams.id', '=', 'team_players.team_id')
            ->select(
                'teams.id',
                'teams.name',
                'teams.sport',
                'teams.coach_name',
                'teams.max_players',
                'teams.status',
                'teams.locked',
                DB::raw('COUNT(team_players.player_id) as player_count')
            )
            ->groupBy(
                'teams.id',
                'teams.name',
                'teams.sport',
                'teams.coach_name',
                'teams.max_players',
                'teams.status',
                'teams.locked'
            )
            ->paginate(10);

        return response()->json($teams);
    }

    public function update(Request $request, $id)
    {
        $team = Team::findOrFail($id);

        $request->validate([
            'name'       => 'required|string|max:255|unique:teams,name,' . $id . ',id,tournament_id,' . $team->tournament_id,
            'type'       => 'required|in:individual,team_event',
            'sport'      => 'required|string|max:50',
            'coach_name' => 'nullable|string|max:100',
        ]);

        $team->update([
            'name'       => $request->name,
            'sport'      => $request->sport,
            'coach_name' => $request->coach_name,
        ]);

        return response()->json([
            'message' => 'Team updated successfully',
            'team'    => $team,
        ]);
    }

    public function destroy($id)
    {
        $team = Team::findOrFail($id);

        $team->delete();

        DB::table('team_players')
            ->where('team_id', $id)
            ->update([
                'deleted_at' => now(),
                'updated_at' => now(),
            ]);

        return response()->json([
            'message' => 'Team deleted successfully',
        ]);
    }

    public function restore($id)
    {
        $team = Team::withTrashed()->findOrFail($id);

        $team->restore();

        DB::table('team_players')
            ->where('team_id', $id)
            ->update([
                'deleted_at' => null,
                'updated_at' => now(),
            ]);

        return response()->json([
            'message' => 'Team restored successfully',
        ]);
    }

    public function trashed()
    {
        $teams = Team::onlyTrashed()
            ->orderBy('deleted_at', 'desc')
            ->paginate(10);

        return response()->json($teams);
    }

    public function updateStatus($id)
    {
        $team = Team::findOrFail($id);

        if ($team->status === 'draft') {
            $team->status = 'active';
        } else {
            $team->status = 'draft';
        }

        $team->save();

        return response()->json([
            'message' => 'Team status updated',
            'status'  => $team->status,
        ]);
    }

    public function togglePublish($id)
    {
        $team = Team::findOrFail($id);

        $playingCount = DB::table('team_players')
            ->where('team_id', $team->id)
            ->where('is_playing', 1)
            ->whereNull('deleted_at')
            ->count();

        if ($playingCount < 2) {
            return response()->json([
                'message' => 'Select 2 players to publish.',
            ], 400);
        }

        // PUBLISH + LOCK
        $team->is_published = 1;
        $team->locked       = 1;

        $team->save();

        return response()->json([
            'message' => 'Team published and locked',
            'team'    => $team,
        ]);
    }

    public function transferPlayer(Request $request)
    {
        $playerId     = $request->player_id;
        $newTeamId    = $request->team_id;
        $tournamentId = $request->tournament_id;

        $oldRecord = DB::table('team_players')
            ->where('player_id', $playerId)
            ->where('tournament_id', $tournamentId)
            ->whereNull('deleted_at')
            ->first();

        if (! $oldRecord) {
            return response()->json([
                "message" => "Player not found in any team",
            ], 404);
        }

        $oldTeam    = Team::findOrFail($oldRecord->team_id);
        $newTeam    = Team::findOrFail($newTeamId);
        $tournament = Tournament::findOrFail($tournamentId);

        if ($tournament->is_published || $oldTeam->locked || $newTeam->locked) {
            return response()->json([
                "message" => "Cannot transfer players. Team is locked.",
            ], 403);
        }

        $count = DB::table('team_players')
            ->where('team_id', $newTeamId)
            ->whereNull('deleted_at')
            ->count();

        if ($count >= $newTeam->max_players) {
            return response()->json([
                "message" => "Team already full",
            ], 400);
        }

        try {
            DB::transaction(function () use ($playerId, $newTeamId, $tournamentId, $oldRecord) {

                // 🔥 STEP 1: SOFT DELETE OLD ENTRY
                DB::table('team_players')
                    ->where('id', $oldRecord->id)
                    ->update([
                        'deleted_at' => now(),
                        'updated_at' => now(),
                    ]);

                // 🔥 STEP 2: INSERT NEW ENTRY
                DB::table('team_players')->updateOrInsert(
                    [
                        'player_id'     => $playerId,
                        'tournament_id' => $tournamentId,
                    ],
                    [
                        'team_id'    => $newTeamId,
                        'deleted_at' => null,
                        'is_playing' => 1,
                        'updated_at' => now(),
                        'created_at' => now(),
                    ]
                );

            });

            // 🔥 AUTO UPDATE TEAM NAME FOR BOTH TEAMS (IMPORTANT FIX)

// OLD TEAM NAME UPDATE
            $oldPlayers = DB::table('team_players')
                ->join('players', 'players.id', '=', 'team_players.player_id')
                ->where('team_players.team_id', $oldTeam->id)
                ->whereNull('team_players.deleted_at')
                ->pluck('players.full_name')
                ->toArray();

            if (count($oldPlayers) > 0) {
                $oldTeam->name = implode(' & ', array_slice($oldPlayers, 0, 2));
            } else {
                $oldTeam->name = "Player " . $oldTeam->id;
            }
            $oldTeam->save();

// NEW TEAM NAME UPDATE
            $newPlayers = DB::table('team_players')
                ->join('players', 'players.id', '=', 'team_players.player_id')
                ->where('team_players.team_id', $newTeam->id)
                ->whereNull('team_players.deleted_at')
                ->pluck('players.full_name')
                ->toArray();

            if (count($newPlayers) > 0) {
                $newTeam->name = implode(' & ', array_slice($newPlayers, 0, 2));
            } else {
                $newTeam->name = "Player " . $newTeam->id;
            }
            $newTeam->save();

            return response()->json([
                "success" => true,
                "message" => "Player transferred successfully",
            ]);

        } catch (\Exception $e) {

            \Log::error("TRANSFER ERROR: " . $e->getMessage());

            return response()->json([
                "success" => false,
                "message" => $e->getMessage(),
            ], 500);
        }
    }

    public function availablePlayers($teamId)
    {
        $team = Team::findOrFail($teamId);

        $players = Player::where('event_id', $team->tournament->event_id)
            ->where('type', $team->type)
            ->whereNotIn('id', function ($query) use ($team) {
                $query->select('player_id')
                    ->from('team_players')
                    ->where('tournament_id', $team->tournament_id)
                    ->whereNull('deleted_at');
            })
            ->get(['id', 'full_name']);

        return response()->json($players);
    }

    public function setPlayingPlayers(Request $request, $teamId)
    {
        $playerIds = $request->player_ids;

        DB::table('team_players')
            ->where('team_id', $teamId)
            ->update(['is_playing' => 0]);

        DB::table('team_players')
            ->where('team_id', $teamId)
            ->whereIn('player_id', $playerIds)
            ->update(['is_playing' => 1]);

        return response()->json([
            "message" => "Playing players updated",
        ]);
    }

    public function unlockTeam($id)
    {
        $team = Team::findOrFail($id);

        $team->locked       = 0;
        $team->is_published = 0;

        $team->save();

        \Log::info("UNLOCK TEAM ID: " . $id . " → locked: " . $team->locked);

        $team->refresh();

        return response()->json([
            'message' => 'Team unlocked successfully',
            'team'    => $team,
        ]);
    }

    public function masterTeams()
    {
        $teams = Team::where('type', 'team_event') // only team events
            ->where('is_published', 1)                 // only published
            ->where('locked', 1)                       // only locked
            ->select('id', 'name', 'status', 'type', 'locked', 'is_published')
            ->get();

        return response()->json([
            'data' => $teams,
        ]);
    }

    public function masterIndividualTeams()
    {
        $teams = Team::where('type', 'team_event') // ✅ only team events
            ->get()
            ->map(function ($team) {

                $playerIds = DB::table('team_players')
                    ->where('team_id', $team->id)
                    ->whereNull('deleted_at')
                    ->pluck('player_id');

                // ❌ skip teams without players
                if ($playerIds->isEmpty()) {
                    return null;
                }

                return [
                    'id'         => $team->id,
                    'name'       => $team->name,
                    'player_ids' => $playerIds,
                    'type'       => $team->type,
                    'locked'     => $team->locked,
                    'status'     => $team->status,
                ];
            })
            ->filter()
            ->values();

        return response()->json([
            'data' => $teams,
        ]);
    }

    public function masterIndividualOnlyTeams()
    {
        $teams = Team::where('type', 'individual') // ✅ individual only
            ->where('locked', 1)
            ->where('is_published', 1) // ✅ only locked teams
            ->get()
            ->map(function ($team) {

                $playerIds = DB::table('team_players')
                    ->where('team_id', $team->id)
                    ->whereNull('deleted_at')
                    ->pluck('player_id');

                if ($playerIds->isEmpty()) {
                    return null;
                }

                return [
                    'id'         => $team->id,
                    'name'       => $team->name,
                    'player_ids' => $playerIds,
                    'type'       => $team->type,
                    'locked'     => $team->locked,
                    'status'     => $team->status,
                ];
            })
            ->filter()
            ->values();

        return response()->json([
            'data' => $teams,
        ]);
    }

    public function totalCount()
    {
        $count = Team::whereNull('deleted_at')->count();
        return response()->json(['total' => $count]);
    }
}
