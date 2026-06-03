<?php
namespace App\Http\Controllers;

use App\Models\ManualMatch;
use App\Models\MatchModel;
use App\Models\Player;
use App\Models\Team;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PlayerController extends Controller
{
    // get all players
    public function index(Request $request)
    {
        $players = Player::orderBy('id', 'desc')->get();

        $histories = $this->buildPlayerHistories($players);

        $data = $players->map(function ($player) use ($histories) {
            $history = $histories[$player->id] ?? [];

            return array_merge($player->toArray(), [
                'history'        => array_values($history),
                'matches_played' => collect($history)->sum('matches_played'),
                'wins'           => collect($history)->sum('wins'),
                'losses'         => collect($history)->sum('losses'),
            ]);
        });

        return response()->json([
            'data'           => $data,
            'total'          => Player::count(),
            'active_count'   => Player::where('is_active', 1)->count(),
            'inactive_count' => Player::where('is_active', 0)->count(),
        ]);
    }

    private function buildPlayerHistories($players): array
    {
        if ($players->isEmpty()) {
            return [];
        }

        $playerIds = $players->pluck('id')->all();

        $pivotRows = DB::table('team_players')
            ->whereIn('player_id', $playerIds)
            ->get(['player_id', 'team_id']);

        if ($pivotRows->isEmpty()) {
            return [];
        }

        $playerTeams = [];
        $allTeamIds  = [];

        foreach ($pivotRows as $row) {
            $playerId = (int) $row->player_id;
            $teamId   = (int) $row->team_id;

            $playerTeams[$playerId][] = $teamId;
            $allTeamIds[$teamId]      = $teamId;
        }

        $allTeamIds = array_values($allTeamIds);

        if (empty($allTeamIds)) {
            return [];
        }

        $teams = Team::withTrashed()
            ->with('tournament')
            ->whereIn('id', $allTeamIds)
            ->get()
            ->keyBy('id');

        $tournamentIds = $teams->pluck('tournament_id')
            ->filter()
            ->unique()
            ->values()
            ->all();

        $tournaments = DB::table('tournaments')
            ->whereIn('id', $tournamentIds)
            ->get()
            ->keyBy('id');

        $regularMatches = MatchModel::where('status', 'completed')
            ->where(function ($q) use ($allTeamIds) {
                $q->whereIn('team_a_id', $allTeamIds)
                    ->orWhereIn('team_b_id', $allTeamIds);
            })
            ->get();

        $manualMatches = ManualMatch::where('status', 'completed')
            ->where(function ($q) use ($allTeamIds) {
                $q->whereIn('team_a_id', $allTeamIds)
                    ->orWhereIn('team_b_id', $allTeamIds);
            })
            ->get();

        $matchesByTeam = [];

        foreach ($regularMatches as $match) {
            $this->indexMatchForTeam($matchesByTeam, 'match-' . $match->id, $match);
        }

        foreach ($manualMatches as $match) {
            $this->indexMatchForTeam($matchesByTeam, 'manual-' . $match->id, $match);
        }

        $historyByPlayer = [];

        foreach ($players as $player) {
            $teamIds = $playerTeams[(int) $player->id] ?? [];

            if (empty($teamIds)) {
                $historyByPlayer[$player->id] = [];
                continue;
            }

            $uniqueMatches = [];

            foreach ($teamIds as $teamId) {
                foreach ($matchesByTeam[$teamId] ?? [] as $entry) {
                    $uniqueMatches[$entry['key']] = $entry['match'];
                }
            }

            $historyByPlayer[$player->id] = $this->summarizeTournamentHistory(
                $teamIds,
                $uniqueMatches,
                $teams,
                $tournaments
            );

        }

        return $historyByPlayer;
    }

    private function indexMatchForTeam(array &$matchesByTeam, string $key, $match): void
    {
        if (! empty($match->team_a_id)) {
            $matchesByTeam[(int) $match->team_a_id][] = [
                'key'   => $key,
                'match' => $match,
            ];
        }

        if (! empty($match->team_b_id)) {
            $matchesByTeam[(int) $match->team_b_id][] = [
                'key'   => $key,
                'match' => $match,
            ];
        }
    }

    private function summarizeTournamentHistory(array $teamIds, array $matches, $teams, $tournaments): array
    {
        $history = [];
        $teamIds = array_map('intval', $teamIds);

        foreach ($matches as $match) {
            $teamAId = (int) ($match->team_a_id ?? 0);
            $teamBId = (int) ($match->team_b_id ?? 0);

            $playerTeamId = null;

            if (in_array($teamAId, $teamIds, true)) {
                $playerTeamId = $teamAId;
            } elseif (in_array($teamBId, $teamIds, true)) {
                $playerTeamId = $teamBId;
            }

            if (! $playerTeamId) {
                continue;
            }

            $team         = $teams->get($playerTeamId);
            $tournamentId = (int) ($match->tournament_id ?? data_get($team, 'tournament_id', 0));

            if (! $tournamentId) {
                continue;
            }

            $tournament = $tournaments->get($tournamentId);

            if (! $tournament) {
                $tournament = DB::table('tournaments')
                    ->where('id', $tournamentId)
                    ->first();
            }

            $key = (string) $tournamentId;

            if (! isset($history[$key])) {
                $history[$key] = [
                    'tournamentId'   => (string) $tournamentId,
                    'tournamentName' => (string) (
                        data_get($tournament, 'name') ?? data_get($tournament, 'tournament_name') ?? data_get($tournament, 'title') ?? data_get($tournament, 'event_name') ?? ('Tournament ' . $tournamentId)
                    ),
                    'sport'          => (string) (
                        data_get($tournament, 'sport_name') ?? data_get($tournament, 'sport') ?? ''
                    ),
                    'venue'          => (string) (
                        data_get($tournament, 'venue_name') ?? data_get($tournament, 'venue') ?? data_get($tournament, 'location') ?? ''
                    ),
                    'result'         => 'Participant',
                    'date'           => (string) ($match->match_date ?? ''),
                    'matches_played' => 0,
                    'wins'           => 0,
                    'losses'         => 0,
                    '_won_final'     => false,
                    '_lost_final'    => false,
                    '_lost_semi'     => false,
                ];
            }

            $history[$key]['matches_played']++;

            if (! empty($match->match_date)) {
                if (empty($history[$key]['date']) || $match->match_date > $history[$key]['date']) {
                    $history[$key]['date'] = (string) $match->match_date;
                }
            }

            if (! empty($match->winner_team_id)) {
                if ((int) $match->winner_team_id === $playerTeamId) {
                    $history[$key]['wins']++;
                } else {
                    $history[$key]['losses']++;
                }
            }

            $round = strtolower(trim((string) ($match->round ?? '')));

            if ($round === 'final') {
                if ((int) $match->winner_team_id === $playerTeamId) {
                    $history[$key]['_won_final'] = true;
                } elseif (! empty($match->winner_team_id)) {
                    $history[$key]['_lost_final'] = true;
                }
            }

            if ($round === 'semi-final' && ! empty($match->winner_team_id) && (int) $match->winner_team_id !== $playerTeamId) {
                $history[$key]['_lost_semi'] = true;
            }
        }

        foreach ($history as &$row) {
            if ($row['_won_final']) {
                $row['result'] = 'Winner';
            } elseif ($row['_lost_final']) {
                $row['result'] = 'Runner-up';
            } elseif ($row['_lost_semi']) {
                $row['result'] = 'Semi-Final';
            }

            unset($row['_won_final'], $row['_lost_final'], $row['_lost_semi']);
        }

        usort($history, function ($a, $b) {
            return strcmp($b['date'] ?? '', $a['date'] ?? '');
        });

        return array_values($history);
    }

    // create player
    public function store(Request $request)
    {
        $request->validate([
            'full_name' => 'required|string|max:255',
        ]);

        $player = Player::create([
            'event_id'    => $request->event_id ?? 1,
            'full_name'   => $request->full_name,
            'gender'      => $request->gender,
            'age_group'   => $request->age_group,
            'skill_level' => $request->skill_level,
            'phone'       => $request->phone,
            'email'       => $request->email,
            'is_active'   => $request->is_active ?? 1,
            'type'        => $request->type ?? 'individual',
        ]);

        return response()->json($player, 201);
    }

    // get single player
    public function show($id)
    {
        $player = Player::with('event')->find($id);

        if (! $player) {
            return response()->json(['message' => 'Player not found'], 404);
        }

        return response()->json($player);
    }

    // update player
    public function update(Request $request, $id)
    {
        $player = Player::find($id);

        if (! $player) {
            return response()->json(['message' => 'Player not found'], 404);
        }

        $player->update($request->all());

        return response()->json($player);
    }

    // delete player
    public function destroy($id)
    {
        $player = Player::find($id);

        if (! $player) {
            return response()->json(['message' => 'Player not found'], 404);
        }

        $player->delete();

        return response()->json(['message' => 'Player deleted successfully']);
    }

    public function restore($id)
    {
        $player = Player::withTrashed()->findorFail($id);

        $player->restore();

        return response()->json(['message' => 'Player restored successfully']);
    }

    public function trashed()
    {
        return response()->json(Player::onlyTrashed()->get());
    }

    public function getDuplicates()
    {
        $players = Player::whereNull('deleted_at')->get();

        $groups = [];

        foreach ($players as $player) {

            $name = preg_replace('/\s+/', ' ', strtolower(trim($player->full_name ?? '')));

            if (! $name) {
                continue;
            }

            if (! isset($groups[$name])) {
                $groups[$name] = [];
            }

            $groups[$name][] = $player;
        }

        $duplicates = [];

        foreach ($groups as $group) {
            if (count($group) > 1) {
                $duplicates[] = array_values($group);
            }
        }

        return response()->json($duplicates);
    }

    public function mergeDuplicates(Request $request)
    {
        $playerIds = $request->input('player_ids');

        if (! $playerIds || count($playerIds) < 2) {
            return response()->json([
                'message' => 'Invalid player group',
            ], 400);
        }

        if (count($playerIds) > 10) {
            return response()->json([
                'message' => 'Too many players selected',
            ], 400);
        }

        // Get players from DB
        $players = Player::whereIn('id', $playerIds)->get();

        if ($players->count() < 2) {
            return response()->json([
                'message' => 'Players not found',
            ], 404);
        }

        $primary = $players->sortByDesc(function ($p) {
            return ! empty($p->email);
        })->first();

        foreach ($players as $p) {
            if (! $primary->email && $p->email) {
                $primary->email = $p->email;
            }

            if (! $primary->phone && $p->phone) {
                $primary->phone = $p->phone;
            }
        }

        $primary->type = 'individual';

        $primary->save();

        // Delete others
        foreach ($players as $p) {
            if ($p->id != $primary->id) {
                $p->delete();
            }
        }

        return response()->json([
            'message' => 'Duplicate players merged successfully',
        ]);
    }

    public function bulkUpload(Request $request)
    {
        $players = $request->input('players', []);

        foreach ($players as $player) {

            $fullName = trim($player['full_name'] ?? '');

            if (! $fullName) {
                continue;
            }

            Player::create([
                'event_id'  => 1,
                'full_name' => $fullName,
                'is_active' => 1,
                'type'      => $player['type'] ?? 'individual',
            ]);
        }

        return response()->json([
            "message" => "Players imported successfully",
        ]);
    }

    public function toggleActive($id)
    {
        $player = Player::find($id);

        if (! $player) {
            return response()->json(['message' => 'Player not found'], 404);
        }

        $player->is_active = ! $player->is_active;
        $player->save();

        return response()->json([
            'message' => 'Player status updated successfully',
            'player'  => $player,
        ]);
    }
}
