<?php
namespace App\Http\Controllers;

use App\Models\MatchModel;
use App\Models\Result;
use App\Models\Stage;
use App\Models\Standing;
use Illuminate\Http\Request;

class StandingController extends Controller
{
    public static function recalculate($eventGroupId)
    {
        // ✅ GET STAGE
        $stage = Stage::where('event_group_id', $eventGroupId)->first();

        if (! $stage) {
            return;
        }

        // ✅ GET ALL MATCHES
        $fixtures = MatchModel::where('event_group_id', $eventGroupId)->get();

        $teamStats = [];

        foreach ($fixtures as $fixture) {

            // ✅ CORRECT TEAM FIELDS (FINAL FIX)
            $home = $fixture->team_a_id;
            $away = $fixture->team_b_id;

            // 🚨 SKIP INVALID
            if (! $home || ! $away) {
                continue;
            }

            // ✅ INIT TEAMS
            foreach ([$home, $away] as $teamId) {
                if (! isset($teamStats[$teamId])) {
                    $teamStats[$teamId] = [
                        'played'    => 0,
                        'won'       => 0,
                        'draw'      => 0,
                        'lost'      => 0,
                        'gf'        => 0,
                        'ga'        => 0,
                        'sets_won'  => 0,
                        'sets_lost' => 0,
                        'points'    => 0,
                    ];
                }
            }

            // ✅ GET RESULT
            $result = Result::where('fixture_id', $fixture->id)->first();

            if (! $result) {
                continue;
            }

            // ✅ PLAYED
            $teamStats[$home]['played']++;
            $teamStats[$away]['played']++;

            // ✅ GOALS
            $teamStats[$home]['gf'] += $result->home_score;
            $teamStats[$home]['ga'] += $result->away_score;

            $teamStats[$away]['gf'] += $result->away_score;
            $teamStats[$away]['ga'] += $result->home_score;

            $sets = json_decode($result->sets, true) ?? [];

            $homeSetsWon  = 0;
            $awaySetsWon  = 0;

            foreach ($sets as $set) {
                $homeScore = $set['home'] ?? 0;
                $awayScore = $set['away'] ?? 0;

                if ($homeScore > $awayScore) {
                    $homeSetsWon++;
                } elseif ($awayScore > $homeScore) {
                    $awaySetsWon++;
                }
            }

            // APPLY
            $teamStats[$home]['sets_won']  += $homeSetsWon;
            $teamStats[$home]['sets_lost'] += $awaySetsWon;

            $teamStats[$away]['sets_won']  += $awaySetsWon;
            $teamStats[$away]['sets_lost'] += $homeSetsWon;

            // DEBUG
            \Log::info("SETS CALC:", [
                "fixture"   => $fixture->id,
                "home_sets" => $homeSetsWon,
                "away_sets" => $awaySetsWon,
            ]);

            // ✅ RESULT LOGIC
            if ($result->home_score > $result->away_score) {
                $teamStats[$home]['won']++;
                $teamStats[$away]['lost']++;
                $teamStats[$home]['points'] += 3;

            } elseif ($result->away_score > $result->home_score) {
                $teamStats[$away]['won']++;
                $teamStats[$home]['lost']++;
                $teamStats[$away]['points'] += 3;

            } else {
                $teamStats[$home]['draw']++;
                $teamStats[$away]['draw']++;
                $teamStats[$home]['points'] += 1;
                $teamStats[$away]['points'] += 1;
            }
        }

        // ❗ CLEAR OLD
        Standing::where('stage_id', $stage->id)->delete();

        $allParticipants = \App\Models\Participant::where('event_group_id', $eventGroupId)->get();

        foreach ($allParticipants as $participant) {
            if (! $participant->team_id) {
                continue;
            }

            if (! isset($teamStats[$participant->team_id])) {
                $teamStats[$participant->team_id] = [
                    'played'    => 0,
                    'won'       => 0,
                    'draw'      => 0,
                    'lost'      => 0,
                    'gf'        => 0,
                    'ga'        => 0,
                    'sets_won'  => 0,
                    'sets_lost' => 0,
                    'points'    => 0,
                ];
            }
        }

        // ✅ INSERT NEW
        foreach ($teamStats as $teamId => $stats) {

            Standing::create([
                'stage_id' => $stage->id,
                'team_id'  => $teamId,
                'played'   => $stats['played'],
                'won'      => $stats['won'],
                'draw'     => $stats['draw'],
                'lost'     => $stats['lost'],
                'gf'       => $stats['gf'],
                'ga'       => $stats['ga'],
                'gd'       => 0,
                'points'   => $stats['points'],
                'sd'       => $stats['gf'] - $stats['ga'], // 🔥 TEMP USE SCORE DIFF
                'position' => 0,

                'h2h'      => 0, // temp, we update later
            ]);
        }

        // ✅ SORT + POSITION
        $standings = Standing::where('stage_id', $stage->id)->get();

        // 🔥 APPLY H2H SORT
        $standings = $standings->sort(function ($a, $b) use ($eventGroupId) {

            // 1️⃣ POINTS
            if ($a->points != $b->points) {
                return $b->points - $a->points;
            }

            // 2️⃣ H2H
            $h2hWinner = self::getHeadToHeadWinner(
                $a->team_id,
                $b->team_id,
                $eventGroupId
            );

            if ($h2hWinner == $a->team_id) {
                return -1;
            }

            if ($h2hWinner == $b->team_id) {
                return 1;
            }

            // 3️⃣ SD (🔥 USE THIS NOW)
            if ($a->sd != $b->sd) {
                return $b->sd - $a->sd;
            }

            // 4️⃣ GF
            return $b->gf - $a->gf;
        });

        $pos = 1;
        foreach ($standings->values() as $row) {

            $h2hValue = 0; // 🔥 DEFAULT 0

            foreach ($standings as $other) {

                if ($row->team_id == $other->team_id) {
                    continue;
                }

                // 🔥 ONLY CHECK TIED TEAMS
                if ($row->points == $other->points) {

                    $winner = self::getHeadToHeadWinner(
                        $row->team_id,
                        $other->team_id,
                        $eventGroupId
                    );

                    if ($winner == $row->team_id) {
                        $h2hValue = 1;
                        break; // 🔥 IMPORTANT STOP AFTER WIN
                    }

                    if ($winner == $other->team_id) {
                        $h2hValue = 0;
                    }
                }
            }

            $row->update([
                'position' => $pos++,
                'h2h'      => $h2hValue,
            ]);
        }
    }

    // 📊 GET STANDINGS
    public function index($eventGroupId)
    {
        $stage = Stage::where('event_group_id', $eventGroupId)->first();

        if (! $stage) {
            return response()->json([
                "success" => true,
                "data"    => [],
            ]);
        }

        $count = Standing::where('stage_id', $stage->id)->count();

        if ($count === 0) {
            self::recalculate($eventGroupId);
        }

        $data = Standing::where('stage_id', $stage->id)
            ->orderBy('position')
            ->get();

        return response()->json([
            "success" => true,
            "data"    => $data,
        ]);
    }

    public function restore($eventGroupId)
    {
        // 🔥 Recalculate standings from results
        self::recalculate($eventGroupId);

        return response()->json([
            "success" => true,
            "message" => "Standings restored successfully",
        ]);
    }

    public function updateStanding(Request $request, $id)
    {
        $standing = Standing::find($id);

        if (! $standing) {
            return response()->json([
                "success" => false,
                "message" => "Standing not found",
            ], 404);
        }

        \Log::info("SD RECEIVED:", [$request->sd]);

        $standing->update([

            'played'   => $request->played ?? $standing->played,
            'won'      => $request->won ?? $standing->won,
            'draw'     => $request->draw ?? $standing->draw,
            'lost'     => $request->lost ?? $standing->lost,

            'gf'       => $request->gf ?? $standing->gf,
            'ga'       => $request->ga ?? $standing->ga,

            // 🔥 IMPORTANT (ALLOW MANUAL OVERRIDE)
            'gd'       => $request->gd ?? 0,

            // 🔥 ADD THIS (YOU MISSED SD COLUMN)
            'sd'       => $request->has('sd') ? $request->sd : $standing->sd,

            'points'   => $request->points ?? $standing->points,
            'position' => $request->position ?? $standing->position,
            'h2h'      => $request->h2h ?? 0,
        ]);

        return response()->json([
            "success" => true,
            "data"    => $standing,
        ]);
    }

    private static function getHeadToHeadWinner($teamA, $teamB, $eventGroupId)
    {
        $matches = MatchModel::where('event_group_id', $eventGroupId)
            ->where(function ($q) use ($teamA, $teamB) {
                $q->where([
                    ['team_a_id', $teamA],
                    ['team_b_id', $teamB],
                ])->orWhere([
                    ['team_a_id', $teamB],
                    ['team_b_id', $teamA],
                ]);
            })
            ->get();

        \Log::info("H2H MATCH COUNT: " . $matches->count());

        if ($matches->isEmpty()) {
            return null;
        }

        $scoreA = 0;
        $scoreB = 0;

        foreach ($matches as $match) {

            $result = Result::where('fixture_id', $match->id)->first();

            if (! $result) {
                continue;
            }

            if ($result->home_score > $result->away_score) {
                if ($match->team_a_id == $teamA) {
                    $scoreA++;
                } else {
                    $scoreB++;
                }

            } elseif ($result->away_score > $result->home_score) {
                if ($match->team_b_id == $teamA) {
                    $scoreA++;
                } else {
                    $scoreB++;
                }

            }
        }

        if ($scoreA > $scoreB) {
            return $teamA;
        }

        if ($scoreB > $scoreA) {
            return $teamB;
        }

        return null;
    }
}
