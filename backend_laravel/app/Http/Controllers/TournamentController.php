<?php
namespace App\Http\Controllers;

use App\Models\EventGroup;
use App\Models\MatchModel;
use App\Models\Participant;
use App\Models\Team;
use App\Models\Tournament;
use App\Models\TournamentSponsor;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class TournamentController extends Controller
{
    public function store(\Illuminate\Http\Request $request)
    {

        \Log::info("TOURNAMENT PAYLOAD:", $request->all());

        try {

            $data = $request->all();

            \Log::info('EVENT GROUPS DATA:', $data['event_groups'] ?? []);

            $venueId = $request->input('venue_id'); // 🔥 FORCE GET

            $venueName = null;

            if ($venueId) {
                $venue     = \App\Models\Venue::find($venueId);
                $venueName = $venue ? $venue->venue_name : null;
            }
            $tournament = Tournament::create([
                'name'                  => $data['name'] ?? 'Tournament',
                'event_id'              => $data['event_id'] ?? null,
                'sport_id'              => $data['sport_id'] ?? null,
                'format'                => $data['format'] ?? 'round_robin',
                'status'                => $data['status'] ?? 'draft',
                'min_players'           => $data['min_players'] ?? 2,
                'max_players'           => $data['max_players'] ?? 2,

                'venue_id'              => $venueId,
                'venue_name'            => $venueName,

                'start_date'            => ! empty($data['start_date']) ? $data['start_date'] : null,
                'end_date'              => ! empty($data['end_date']) ? $data['end_date'] : null,
                'registration_due_date' => ! empty($data['registration_due_date']) ? $data['registration_due_date'] : null,

                'contact_name'          => $data['contact_name'] ?? null,
                'contact_email'         => $data['contact_email'] ?? null,
                'contact_phone'         => $data['contact_phone'] ?? null,

                'city'                  => $data['city'] ?? null,
                'state'                 => $data['state'] ?? null,
                'pin_code'              => $data['pin_code'] ?? null,

                'description'           => $data['description'] ?? null,
            ]);

            if ($request->hasFile('banner')) {
                $path               = $request->file('banner')->store('tournaments', 'public');
                $tournament->banner = $path;
                $tournament->save();
            }

            // ================= EVENT GROUPS =================
            if (! empty($data['event_groups'])) {

                foreach ($data['event_groups'] as $group) {

                    $eventGroup = EventGroup::create([
                        'tournament_id'    => $tournament->id,
                        'event_name'       => $group['event_name'] ?? null,
                        'sport_name'       => $group['event_name'] ?? null,
                        'format'           => $group['format'] ?? 'round_robin',
                        'participant_type' => $group['participant_type'] ?? 'Team',
                        'gender'           => $group['gender'] ?? 'Open',
                        'max_participants' => $group['max_participants'] ?? 0,
                    ]);

                    $stage = \App\Models\Stage::create([
                        'tournament_id'  => $tournament->id,
                        'event_group_id' => $eventGroup->id,
                        'name'           => 'League Stage',
                        'type'           => 'league',
                        'status'         => 'active',
                    ]);

                    // ================= PARTICIPANTS =================
                    if (! empty($group['participants'])) {
                        foreach ($group['participants'] as $p) {

                            Participant::create([
                                'event_group_id' => $eventGroup->id,
                                'name'           => $p['name'] ?? null,
                                'team_id'        => $p['team_id'] ?? null,
                            ]);
                        }
                    }

                }
            }

            $tournament->load([
                'eventGroups',
            ]);

            // 🔥 MANUAL MATCHES ATTACH (FINAL FIX)
            foreach ($tournament->eventGroups as $group) {

                if ($group->format === 'custom') {

                    $group->matches = \App\Models\ManualMatch::where('event_group_id', $group->id)
                        ->whereNull('deleted_at')
                        ->orderBy('round_order')
                        ->orderBy('match_order')
                        ->get();

                } else {
                    // keep existing matches for RR/KO
                    $group->load('matches');
                }
            }

            return response()->json([
                "success" => true,
                "data"    => [
                    "id"           => $tournament->id,
                    "event_groups" => $tournament->eventGroups->map(function ($g) {

                        $stage = \App\Models\Stage::where('event_group_id', $g->id)->first();

                        return [
                            "id"       => $g->id,
                            "stage_id" => $stage?->id, // 🔥 ADD THIS
                        ];
                    }),
                ],
            ], 201);

        } catch (\Exception $e) {

            return response()->json([
                "success" => false,
                "message" => $e->getMessage(),
            ], 500);
        }
    }

    public function publish($id)
    {
        $tournament = Tournament::findOrFail($id);

        $teams = Team::where('tournament_id', $tournament->id)->get();

        $warnings = [];

        foreach ($teams as $team) {

            $playerCount = \DB::table('team_players')
                ->where('team_id', $team->id)
                ->whereNull('deleted_at')
                ->count();

            if ($playerCount < $tournament->min_players) {

                $warnings[] = "Team {$team->name} has only {$playerCount} players. Minimum required is {$tournament->min_players}";
            }
        }

        if (! empty($warnings)) {
            return response()->json([
                "status"   => "warning",
                "messages" => $warnings,
            ]);
        }

        if ($teams->count() == 0) {
            return response()->json([
                "message" => "Cannot publish tournament without teams",
            ], 400);
        }

        $tournament->is_published = true;
        $tournament->locked_at    = now();
        $tournament->save();

        return response()->json([
            "status"  => "success",
            "message" => "Tournament published successfully and teams locked",
        ]);
    }

    public function unlock($id)
    {
        $tournament = Tournament::findOrFail($id);

        // Allow only Admin or Super Admin
        if (! in_array(auth()->user()->role_id, [1, 2])) {
            return response()->json([
                "message" => "Unauthorized",
            ], 403);
        }

        $tournament->is_published = false;
        $tournament->locked_at    = null;
        $tournament->save();

        Log::info("Tournament {$tournament->id} unlocked by " . auth()->user()->name);

        return response()->json([
            "message" => "Tournament unlocked. Teams can be edited again.",
        ]);
    }

    public function index()
    {
        return Tournament::whereNull('deleted_at')
            ->with(['eventGroups.participants', 'eventGroups.matches'])
            ->get()
            ->map(function ($t) {
                return [
                    'id'            => $t->id,
                    'name'          => $t->name,
                    'type'          => $t->type,
                    'status'        => $t->status,
                    'start_date'    => $t->start_date,
                    'end_date'      => $t->end_date,
                    'venue_name'    => $t->venue_name,
                    'banner'        => ! empty($t->banner)
                        ? asset('storage/' . $t->banner)
                        : null,
                    'fixture_image' => ! empty($t->fixture_image)
                        ? asset('storage/' . $t->fixture_image)
                        : null,
                    'created_at'    => $t->created_at,
                    'updated_at'    => $t->updated_at,

                    'eventGroups'   => $t->eventGroups->map(function ($g) {
                        return [
                            'id'               => $g->id,
                            'event_name'       => $g->event_name,
                            'format'           => $g->format,
                            'participant_type' => $g->participant_type,
                            'gender'           => $g->gender,
                            'participants'     => $g->participants->map(fn($p) => [
                                'id'      => $p->id,
                                'team_id' => $p->team_id,
                                'name'    => $p->name,
                                'team'    => null,
                            ]),
                            'matches'          => $g->matches->map(fn($m) => [
                                'id'             => $m->id,
                                'status'         => $m->status,
                                'winner_team_id' => $m->winner_team_id,
                                'team_a_id'      => $m->team_a_id,
                                'team_b_id'      => $m->team_b_id,
                                'team_a_name'    => $m->team_a_name,
                                'team_b_name'    => $m->team_b_name,
                                'round'          => $m->round,
                                'match_number'   => $m->match_number ?? 0,
                                'round_index'    => $m->round_index ?? 0,
                                'match_index'    => $m->match_index ?? 0,
                                'match_date'     => $m->match_date,
                                'match_time'     => $m->match_time,
                                'court'          => $m->court,
                            ]),
                        ];
                    }),
                ];
            });
    }

    public function addEventGroup(Request $request, $id)
    {
        $tournament = Tournament::findOrFail($id);

        // Block if published
        if ($tournament->status !== 'draft') {
            return response()->json([
                'success' => false,
                'message' => 'Cannot modify published tournament',
            ], 400);
        }

        // Validation
        $validated = $request->validate([
            'event_name'       => 'required|string|max:255',
            'format'           => 'required|in:round_robin,knockout,custom',
            'participant_type' => 'required|in:Team,Individual,Pair',
            'gender'           => 'nullable|in:Open,Men,Women,Mixed',
            'max_participants' => 'nullable|integer|min:1',
        ]);

        // Create event group
        $eventGroup = EventGroup::create([
            'tournament_id'    => $tournament->id,
            'event_name'       => $validated['event_name'],
            'sport_name'       => $validated['event_name'], // optional mapping
            'format'           => $validated['format'],
            'participant_type' => $validated['participant_type'],
            'gender'           => $validated['gender'] ?? 'Open',
            'max_participants' => $validated['max_participants'] ?? 0,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Event group added successfully',
            'data'    => $eventGroup,
        ]);
    }

    public function addParticipant(Request $request, $id)
    {
        $eventGroup = EventGroup::findOrFail($id);

        $tournament = Tournament::findOrFail($eventGroup->tournament_id);

        // Block if published
        if ($tournament->status !== 'draft') {
            return response()->json([
                'success' => false,
                'message' => 'Cannot modify published tournament',
            ], 400);
        }

        // Validation
        $validated = $request->validate([
            'team_id' => 'nullable|exists:teams,id',
            'name'    => 'nullable|string|max:255',
            'email'   => 'nullable|email',
            'phone'   => 'nullable|string',
            'seed'    => 'nullable|string',
        ]);

        // Prevent duplicate team
        if (! empty($validated['team_id'])) {
            $exists = Participant::where('event_group_id', $eventGroup->id)
                ->where('team_id', $validated['team_id'])
                ->exists();

            if ($exists) {
                return response()->json([
                    'success' => false,
                    'message' => 'Team already added in this event',
                ], 400);
            }
        }

        // Max participants check
        if ($eventGroup->max_participants > 0) {
            $count = Participant::where('event_group_id', $eventGroup->id)->count();

            if ($count >= $eventGroup->max_participants) {
                return response()->json([
                    'success' => false,
                    'message' => 'Max participants reached',
                ], 400);
            }
        }

        $name = $validated['name'] ?? null;

        if (! empty($validated['team_id'])) {
            $team = \App\Models\Team::find($validated['team_id']);
            $name = $team ? $team->name : null;
        }

        if (empty($name)) {
            return response()->json([
                'success' => false,
                'message' => 'Name is required',
            ], 400);
        }

        // Create participant
        $participant = Participant::create([
            'event_group_id' => $eventGroup->id,
            'team_id'        => $validated['team_id'] ?? null,
            'name'           => $name,
            'email'          => $validated['email'] ?? null,
            'phone'          => $validated['phone'] ?? null,
            'seed'           => $validated['seed'] ?? null,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Participant added successfully',
            'data'    => $participant,
        ]);
    }

    private function nextPowerOfTwo($n)
    {
        return pow(2, ceil(log($n, 2)));
    }

    private function getRoundName($roundIndex, $totalRounds)
    {
        $roundsLeft = $totalRounds - $roundIndex;

        if ($roundsLeft == 1) {
            return 'Final';
        }

        if ($roundsLeft == 2) {
            return 'Semi-Final';
        }

        if ($roundsLeft == 3) {
            return 'Quarter-Final';
        }

        // Dynamic naming for large tournaments
        $teams = pow(2, $roundsLeft);

        return "Round of " . $teams;
    }

    public function storeMatches(Request $request, $id)
    {
        $eventGroup = EventGroup::findOrFail($id);
        $tournament = Tournament::findOrFail($eventGroup->tournament_id);

        if ($tournament->status !== 'draft') {
            return response()->json([
                'success' => false,
                'message' => 'Cannot modify published tournament',
            ], 400);
        }

        $validated = $request->validate([
            'matches'               => 'nullable|array',
            'matches.*.team_a_id'   => 'nullable|integer',
            'matches.*.team_b_id'   => 'nullable|integer',
            'matches.*.team_a_name' => 'nullable|string',
            'matches.*.team_b_name' => 'nullable|string',
        ]);

        $matchesInput = $validated['matches'] ?? [];

        // ==============================
        // ✅ CUSTOM FORMAT (MANUAL ONLY)
        // ==============================
        if ($eventGroup->format === 'custom') {

            foreach ($matchesInput as $m) {

                // 🔥 IF ID EXISTS → UPDATE
                if (! empty($m['id'])) {

                    $match = MatchModel::find($m['id']);

                    if ($match) {
                        $match->update([
                            'team_a_id'   => $m['team_a_id'] ?? null,
                            'team_a_name' => $m['team_a_name'] ?? null,
                            'team_b_id'   => $m['team_b_id'] ?? null,
                            'team_b_name' => $m['team_b_name'] ?? null,
                            'match_date'  => $m['match_date'] ?? $match->match_date,
                            'match_time'  => $m['match_time'] ?? $match->match_time,
                            'court'       => $m['court'] ?? $match->court,
                            'status'      => $m['status'] ?? $match->status,
                        ]);
                    }

                } else {
                    // 🔥 CREATE NEW
                    MatchModel::create([
                        'tournament_id'  => $eventGroup->tournament_id,
                        'event_group_id' => $eventGroup->id,
                        'team_a_id'      => $m['team_a_id'] ?? null,
                        'team_a_name'    => $m['team_a_name'] ?? null,
                        'team_b_id'      => $m['team_b_id'] ?? null,
                        'team_b_name'    => $m['team_b_name'] ?? null,
                        'round'          => 'Manual',
                        'round_index'    => 0,
                        'match_index'    => MatchModel::where('event_group_id', $eventGroup->id)->count(),
                        'match_date'     => $m['match_date'] ?? now()->toDateString(),
                        'match_time'     => $m['match_time'] ?? null,
                        'court'          => $m['court'] ?? null,
                        'status'         => $m['status'] ?? 'scheduled',
                    ]);
                }
            }

            return response()->json([
                'success' => true,
                'message' => 'Custom match saved successfully',
            ]);
        }

        // ==============================
        // ✅ ROUND ROBIN FIX (ADD HERE)
        // ==============================
        if ($eventGroup->format === 'round_robin') {

            $hasMatches = MatchModel::where('event_group_id', $eventGroup->id)->exists();

            if ($hasMatches) {
                return response()->json([
                    'success' => true,
                    'message' => 'Matches already exist, skipping generation',
                ]);
            }

            // ==============================
            // 🔥 CREATE PARTICIPANTS (MOVE HERE)
            // ==============================
            $existingParticipants = Participant::where('event_group_id', $eventGroup->id)->count();

            if ($existingParticipants === 0) {

                foreach ($matchesInput as $m) {

                    if (! empty($m['team_a_name']) && $m['team_a_name'] !== 'BYE') {
                        Participant::create([
                            'event_group_id' => $eventGroup->id,
                            'team_id'        => $m['team_a_id'] ?? null,
                            'name'           => $m['team_a_name'],
                        ]);
                    }

                    if (! empty($m['team_b_name']) && $m['team_b_name'] !== 'BYE') {
                        Participant::create([
                            'event_group_id' => $eventGroup->id,
                            'team_id'        => $m['team_b_id'] ?? null,
                            'name'           => $m['team_b_name'],
                        ]);
                    }
                }
            }

            // 🔥 NOW FETCH PARTICIPANTS (AFTER CREATION ✅)
            $participants = Participant::where('event_group_id', $eventGroup->id)
                ->get()
                ->unique('name') // 🔥 IMPORTANT
                ->values();

            \Log::info("RR PARTICIPANTS COUNT: " . count($participants));

            $matches = [];

            for ($i = 0; $i < count($participants); $i++) {
                for ($j = $i + 1; $j < count($participants); $j++) {

                    $teamA = $participants[$i];
                    $teamB = $participants[$j];

                    $matches[] = [
                        'tournament_id'  => $eventGroup->tournament_id, // 🔥 ADD THIS
                        'event_group_id' => $eventGroup->id,
                        'team_a_id'      => $teamA->team_id,
                        'team_a_name'    => $teamA->name,
                        'team_b_id'      => $teamB->team_id,
                        'team_b_name'    => $teamB->name,
                        'round'          => 'Round Robin',
                        'round_index'    => 0,
                        'match_index'    => count($matches),
                        'status'         => 'scheduled',
                    ];
                }
            }

            foreach ($matches as $m) {
                MatchModel::create($m);
            }

            // 🔥 CREATE INITIAL STANDINGS (ZERO VALUES)
            \App\Http\Controllers\StandingController::recalculate($eventGroup->id);

            return response()->json([
                'success' => true,
                'message' => 'Round Robin fixtures created',
            ]);
        }

        // 🔥 DELETE ONLY FOR KNOCKOUT
        if ($eventGroup->format === 'knockout') {
            MatchModel::where('event_group_id', $eventGroup->id)->delete();
        }

        // ==============================
        // 🔥 AUTO CREATE PARTICIPANTS
        // ==============================

        // 🔥 RESET ONLY FOR RR
        if ($eventGroup->format === 'round_robin') {
            Participant::where('event_group_id', $eventGroup->id)->delete();
        }

        $existingParticipants = Participant::where('event_group_id', $eventGroup->id)->count();

        if ($eventGroup->format === 'round_robin') {

            $tempParticipants = [];

            foreach ($matchesInput as $m) {

                if ($m['team_a_name'] === 'BYE') {
                    $m['team_a_id'] = null;
                }

                if ($m['team_b_name'] === 'BYE') {
                    $m['team_b_id'] = null;
                }

                if (! empty($m['team_a_name']) && $m['team_a_name'] !== 'BYE') {
                    $tempParticipants[] = [
                        'team_id' => $m['team_a_id'] ?? null,
                        'name'    => $m['team_a_name'],
                    ];
                }

                if (! empty($m['team_b_name']) && $m['team_b_name'] !== 'BYE') {
                    $tempParticipants[] = [
                        'team_id' => $m['team_b_id'] ?? null,
                        'name'    => $m['team_b_name'],
                    ];
                }
            }

            $tempParticipants = collect($tempParticipants)
                ->unique('name')
                ->values();

            foreach ($tempParticipants as $p) {
                Participant::create([
                    'event_group_id' => $eventGroup->id,
                    'team_id'        => $p['team_id'],
                    'name'           => $p['name'],
                ]);
            }
        }

        // ================= EXTRACT PARTICIPANTS =================
        $participants = Participant::where('event_group_id', $eventGroup->id)
            ->get()
            ->map(function ($p) {
                return [
                    'id'   => $p->team_id,
                    'name' => $p->name,
                ];
            })
            ->unique('name')
            ->values()
            ->toArray();

        // Remove duplicates
        $participants = array_values($participants);

        // 🔥 FIX: Remove any accidental TBD from first round
        $participants = array_map(function ($t) {
            if ($t['name'] === 'TBD') {
                return ['id' => null, 'name' => 'BYE'];
            }
            return $t;
        }, $participants);

        $totalTeams = count($participants);

        // ================= NORMALIZE =================
        $bracketSize = $this->nextPowerOfTwo($totalTeams);
        $byes        = $bracketSize - $totalTeams;

        $realTeams = $participants;

        while (count($realTeams) < $bracketSize) {
            $realTeams[] = [
                'id'   => null,
                'name' => 'BYE',
            ];
        }

        $nonBye = collect($realTeams)
            ->filter(fn($t) => $t['name'] !== 'BYE')
            ->shuffle()
            ->values()
            ->toArray();

        $bye = collect($realTeams)
            ->filter(fn($t) => $t['name'] === 'BYE')
            ->values()
            ->toArray();

        // 🔥 EVENLY DISTRIBUTE BYE (FINAL FIX)

        $realTeams = [];

        $byeCount  = count($bye);
        $teamIndex = 0;
        $byeIndex  = 0;

        while ($teamIndex < count($nonBye) || $byeIndex < $byeCount) {

            // add real team
            if ($teamIndex < count($nonBye)) {
                $realTeams[] = $nonBye[$teamIndex++];
            }

            // add BYE only if needed
            if ($byeIndex < $byeCount) {
                $realTeams[] = $bye[$byeIndex++];
            }
        }

        $currentRound = [];
        $roundIndex   = 0;
        $matchIndex   = 0;

        // ✅ STEP 3: PAIR SAFELY (NO BYE vs BYE)
        for ($i = 0; $i < $bracketSize; $i += 2) {

            $teamA = $realTeams[$i];
            $teamB = $realTeams[$i + 1];

            // 🔥 FIX: prevent BYE vs BYE
            if ($teamA['name'] === 'BYE' && $teamB['name'] === 'BYE') {

                for ($j = $i + 2; $j < count($realTeams); $j++) {
                    if ($realTeams[$j]['name'] !== 'BYE') {

                        // swap
                        $temp              = $realTeams[$i + 1];
                        $realTeams[$i + 1] = $realTeams[$j];
                        $realTeams[$j]     = $temp;

                        $teamB = $realTeams[$i + 1];
                        break;
                    }
                }
            }

            $currentRound[] = [
                'team_a_id'   => $teamA['id'],
                'team_a_name' => $teamA['name'],
                'team_b_id'   => $teamB['id'],
                'team_b_name' => $teamB['name'],
                'round_index' => $roundIndex,
                'match_index' => $matchIndex++,
            ];
        }

        // ================= NEXT ROUNDS =================
        $rounds = [];

        while (count($currentRound) > 1) {

            $rounds[] = $currentRound;

            $nextRound = [];

            for ($i = 0; $i < count($currentRound); $i += 2) {
                $nextRound[] = [
                    'team_a_id'   => null,
                    'team_a_name' => 'TBD',
                    'team_b_id'   => null,
                    'team_b_name' => 'TBD',
                    'round_index' => $roundIndex + 1,
                    'match_index' => count($nextRound),
                ];
            }

            $currentRound = $nextRound;
            $roundIndex++;
        }

        $rounds[] = $currentRound;

        // ================= FLATTEN =================
        $allMatches  = [];
        $totalRounds = count($rounds);

        foreach ($rounds as $rIndex => $matches) {
            foreach ($matches as $mIndex => $m) {

                $allMatches[] = [
                    'event_group_id' => $eventGroup->id,
                    'team_a_id'      => $m['team_a_id'],
                    'team_a_name'    => $m['team_a_name'],
                    'team_b_id'      => $m['team_b_id'],
                    'team_b_name'    => $m['team_b_name'],
                    'round'          => $this->getRoundName($rIndex, $totalRounds),
                    'round_index'    => $rIndex,
                    'match_index'    => $mIndex,
                ];
            }
        }

        // ================= SAVE =================
        $createdMatches = [];

                                                                                                     // 🔥 AUTO SCHEDULING (RESTORE)
        $startTime     = \Carbon\Carbon::createFromTime(10, 0);                                      // 10:00 AM
        $matchDuration = 90;                                                                         // minutes
        $courts        = ['Court 1', 'Court 2', 'Court 3', 'Court 4', 'Center Court', 'Main Court']; // or from DB

        $currentTime = clone $startTime;
        $courtIndex  = 0;

        foreach ($allMatches as $m) {

            $match = MatchModel::create([
                'tournament_id'  => $tournament->id,
                'event_group_id' => $m['event_group_id'],
                'team_a_id'      => $m['team_a_id'],
                'team_a_name'    => $m['team_a_name'],
                'team_b_id'      => $m['team_b_id'],
                'team_b_name'    => $m['team_b_name'],
                'round'          => $m['round'],
                'round_index'    => $m['round_index'],
                'match_index'    => $m['match_index'],

                'status'         => 'scheduled',

                // 🔥 AUTO ASSIGN
                'match_date'     => now()->toDateString(),
                'match_time'     => $currentTime->format('H:i'),
                'court'          => $courts[$courtIndex],
            ]);

            $courtIndex = ($courtIndex + 1) % count($courts);

            if ($courtIndex === 0) {
                $currentTime->addMinutes($matchDuration);
            }

            $createdMatches[] = $match;
        }

        \App\Http\Controllers\StandingController::recalculate($eventGroup->id);

        return response()->json([
            'success' => true,
            'message' => 'Matches generated successfully',
            'data'    => $createdMatches,
        ]);
    }

    public function updateFixtureTeams(Request $request, $matchId)
    {
        $match = MatchModel::findOrFail($matchId);

        // ❌ block completed match
        if ($match->status === 'completed') {
            return response()->json([
                'success' => false,
                'message' => 'Cannot edit completed match',
            ], 400);
        }

        $validated = $request->validate([
            'team_a_name' => 'required|string',
            'team_b_name' => 'required|string',
        ]);

        // ❌ same team check
        if ($validated['team_a_name'] === $validated['team_b_name']) {
            return response()->json([
                'success' => false,
                'message' => 'Same team not allowed',
            ], 400);
        }

        // 🔥 TRUE SWAP LOGIC (ADD THIS BLOCK)

        $allMatches = MatchModel::where('event_group_id', $match->event_group_id)->get();

        $oldA = $match->team_a_name;
        $oldB = $match->team_b_name;

        $oldAId = $match->team_a_id;
        $oldBId = $match->team_b_id;

        $newA = $validated['team_a_name'];
        $newB = $validated['team_b_name'];

        foreach ($allMatches as $m) {

            if ($m->id == $match->id) {
                continue;
            }

            // swap A
            if ($m->team_a_name === $newA) {
                $m->team_a_name = $oldA;
                $m->team_a_id   = $oldAId;
            } elseif ($m->team_b_name === $newA) {
                $m->team_b_name = $oldA;
                $m->team_b_id   = $oldAId;
            }

            // swap B
            if ($m->team_a_name === $newB) {
                $m->team_a_name = $oldB;
                $m->team_a_id   = $oldBId;
            } elseif ($m->team_b_name === $newB) {
                $m->team_b_name = $oldB;
                $m->team_b_id   = $oldBId;
            }

            $m->save();
        }

        $match->update([
            'team_a_name' => $validated['team_a_name'],
            'team_b_name' => $validated['team_b_name'],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Fixture updated successfully',
        ]);
    }

    // ==============================
// 🔥 CLEAR FUTURE ROUNDS
// ==============================
    private function clearNextRounds($match)
    {
        $nextMatches = MatchModel::where('event_group_id', $match->event_group_id)
            ->where('round_index', '>', $match->round_index)
            ->get();

        foreach ($nextMatches as $m) {
            $m->update([
                'team_a_id'        => null,
                'team_a_name'      => 'TBD',
                'team_b_id'        => null,
                'team_b_name'      => 'TBD',
                'winner_team_id'   => null,
                'winner_team_name' => null,
                'status'           => 'scheduled',
            ]);
        }
    }

    public function publishTournament($id)
    {
        $tournament = Tournament::findOrFail($id);

        // already published
        if ($tournament->status === 'published') {
            return response()->json([
                'success' => false,
                'message' => 'Tournament already published',
            ], 400);
        }

        // get event groups
        $eventGroups = EventGroup::where('tournament_id', $id)->get();

        if ($eventGroups->isEmpty()) {
            return response()->json([
                'success' => false,
                'message' => 'Add at least one event group',
            ], 400);
        }

        // check participants
        foreach ($eventGroups as $group) {
            $count = Participant::where('event_group_id', $group->id)->count();

            if ($count == 0) {
                return response()->json([
                    'success' => false,
                    'message' => 'Each event group must have participants',
                ], 400);
            }
        }

        // LOCK TEAMS
        $teamIds = Participant::whereNotNull('team_id')
            ->pluck('team_id')
            ->unique();

        \App\Models\Team::whereIn('id', $teamIds)->update([
            'locked' => 1,
        ]);

        // publish
        $tournament->update([
            'status' => 'published',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Tournament published successfully',
        ]);
    }

    public function show($id)
    {
        $tournament = Tournament::with([
            'eventGroups.participants.team.players',
            'eventGroups.matches',
            'eventGroups.stage',
        ])->findOrFail($id);

        foreach ($tournament->eventGroups as $group) {

            if ($group->participants && $group->participants->count() > 0) {
                continue;
            }

            $teamNames = [];

            foreach ($group->matches as $match) {
                if (! empty($match->team_a_name) && $match->team_a_name !== 'TBD') {
                    $teamNames[] = $match->team_a_name;
                }
                if (! empty($match->team_b_name) && $match->team_b_name !== 'TBD') {
                    $teamNames[] = $match->team_b_name;
                }
            }

            $teamNames = array_unique($teamNames);

            $teams = \App\Models\Team::whereIn('name', $teamNames)
                ->with('players')
                ->get();

            $participants = $teams->map(function ($team) {
                return [
                    'team_id' => $team->id,
                    'team'    => [
                        'name'    => $team->name,
                        'players' => $team->players->map(function ($p) {
                            return [
                                'full_name' => $p->full_name,
                            ];
                        }),
                    ],
                ];
            });

            $group->setRelation('participants', $participants);
        }

        return response()->json([
            'success' => true,
            'data'    => [
                'id'                    => $tournament->id,
                'name'                  => $tournament->name,
                'event_id'              => $tournament->event_id,
                'sport_id'              => $tournament->sport_id,

                // 🔥 IMPORTANT
                'start_date'            => $tournament->start_date,
                'end_date'              => $tournament->end_date,
                'registration_due_date' => $tournament->registration_due_date,

                'contact_name'          => $tournament->contact_name,
                'contact_email'         => $tournament->contact_email,
                'contact_phone'         => $tournament->contact_phone,

                'city'                  => $tournament->city,
                'state'                 => $tournament->state,
                'pin_code'              => $tournament->pin_code,

                'description'           => $tournament->description,
                'venue_name'            => $tournament->venue_name,

                'banner'                => ! empty($tournament->banner)
                    ? asset('storage/' . $tournament->banner)
                    : null,

                'fixture_image'         => ! empty($tournament->fixture_image)
                    ? asset('storage/' . $tournament->fixture_image)
                    : null,

                'eventGroups'           => $tournament->eventGroups->values()->map(function ($g) {
                    return [
                        'id'               => $g->id,
                        'stage_id'         => optional($g->stage)->id,
                        'event_name'       => $g->event_name,
                        'sport_name'       => $g->sport_name,
                        'format'           => $g->format,
                        'participant_type' => $g->participant_type,
                        'gender'           => $g->gender,

                        // ✅ PARTICIPANTS
                        'participants'     => $g->participants->map(function ($p) {
                            return [
                                'id'      => $p->id,
                                'team_id' => $p->team_id,
                                'name'    => $p->name,
                                'team'    => $p->team ?? null,
                            ];
                        }),

                        // 🔥🔥🔥 MOST IMPORTANT FIX
                        'matches'          => $g->matches->values()->map(function ($m) {
                            return [
                                'id'               => $m->id,
                                'team_a_id'        => $m->team_a_id,
                                'team_b_id'        => $m->team_b_id,
                                'team_a_name'      => $m->team_a_name,
                                'team_b_name'      => $m->team_b_name,
                                'round'            => $m->round,
                                'match_number'     => $m->match_number,
                                'round_index'      => $m->round_index,
                                'match_index'      => $m->match_index,
                                'match_date'       => $m->match_date,
                                'match_time'       => $m->match_time,
                                'court'            => $m->court,
                                'status'           => $m->status,
                                'winner_team_id'   => $m->winner_team_id,
                                'winner_team_name' => $m->winner_team_name,
                            ];
                        })->values(),
                    ];
                })->values(),
            ],
        ]);
    }

    public function update(Request $request, $id)
    {
        $tournament = Tournament::findOrFail($id);

        $data = $request->all();

        $venueId = $request->input('venue_id'); // 🔥 FORCE GET

        $venueName = null;

        if ($venueId) {
            $venue     = \App\Models\Venue::find($venueId);
            $venueName = $venue ? $venue->venue_name : null;
        }

        // ================= UPDATE TOURNAMENT =================
        $tournament->update([
            'name'                  => $data['name'] ?? $tournament->name,
            'event_id'              => $data['event_id'] ?? null,
            'sport_id'              => $data['sport_id'] ?? null,
            'format'                => $data['format'] ?? 'round_robin',
            'status'                => $data['status'] ?? 'draft',

            'start_date'            => ! empty($data['start_date']) ? $data['start_date'] : null,
            'end_date'              => ! empty($data['end_date']) ? $data['end_date'] : null,
            'registration_due_date' => ! empty($data['registration_due_date']) ? $data['registration_due_date'] : null,

            'contact_name'          => $data['contact_name'] ?? null,
            'contact_email'         => $data['contact_email'] ?? null,
            'contact_phone'         => $data['contact_phone'] ?? null,

            'city'                  => $data['city'] ?? null,
            'state'                 => $data['state'] ?? null,
            'pin_code'              => $data['pin_code'] ?? null,

            'description'           => $data['description'] ?? null,
            'venue_id'              => $venueId,
            'venue_name'            => $venueName,
        ]);

        // ================= EVENT GROUPS =================
        // ================= DELETE REMOVED EVENT GROUPS =================

        $existingGroupIds = EventGroup::where('tournament_id', $tournament->id)
            ->pluck('id')
            ->toArray();

        $incomingGroupIds = collect($data['event_groups'] ?? [])
            ->filter(fn($g) => isset($g['id']) && $g['id'] != null)
            ->pluck('id')
            ->toArray();

        $groupsToDelete = array_diff($existingGroupIds, $incomingGroupIds);

        if (! empty($groupsToDelete)) {

            foreach ($groupsToDelete as $groupId) {

                $group = EventGroup::find($groupId);
                if (! $group) {
                    continue;
                }

                // 🔥 DO NOT DELETE IF MATCHES EXIST
                $hasMatches = \App\Models\MatchModel::where('event_group_id', $groupId)->exists();

                if ($hasMatches) {
                    continue; // keep group if matches exist
                }

                Participant::where('event_group_id', $groupId)->delete();
                EventGroup::where('id', $groupId)->delete();
            }
        }

        if (! empty($data['event_groups'])) {

            foreach ($data['event_groups'] as $group) {

                // ✅ UPDATE EXISTING EVENT GROUP
                $isNewGroup = false;

                if (! empty($group['id']) && EventGroup::where('id', $group['id'])->exists()) {

                    $eventGroup = EventGroup::find($group['id']);

                    $hasMatchesInGroup = \App\Models\MatchModel::where('event_group_id', $eventGroup->id)->exists();

                    if ($eventGroup && ! $hasMatchesInGroup) {
                        $eventGroup->update([
                            'event_name'       => $group['event_name'] ?? null,
                            'sport_name'       => $group['sport_name'] ?? null,
                            'format'           => $group['format'] ?? 'round_robin',
                            'participant_type' => $group['participant_type'] ?? 'Team',
                            'gender'           => $group['gender'] ?? 'Open',
                            'max_participants' => $group['max_participants'] ?? 0,
                        ]);
                    }

                } else {

                    $isNewGroup = false; // 🔥 IMPORTANT FIX

                    // 🔥 CHECK EXISTING GROUP BY NAME
                    $existing = EventGroup::where('tournament_id', $tournament->id)
                        ->where('event_name', $group['event_name'])
                        ->first();

                    if ($existing) {

                        $eventGroup = $existing;

                    } else {

                        $isNewGroup = true;

                        $eventGroup = EventGroup::create([
                            'tournament_id'    => $tournament->id,
                            'event_name'       => $group['event_name'] ?? null,
                            'sport_name'       => $group['sport_name'] ?? null,
                            'format'           => $group['format'] ?? 'round_robin',
                            'participant_type' => $group['participant_type'] ?? 'Team',
                            'gender'           => $group['gender'] ?? 'Men',
                            'max_participants' => $group['max_participants'] ?? 0,
                        ]);
                    }
                }
                $hasMatchesInGroup = \App\Models\MatchModel::where('event_group_id', $eventGroup->id)->exists();

                // ================= PARTICIPANTS =================

                if (isset($group['participants']) && ! $hasMatchesInGroup) {

                    foreach ($group['participants'] as $p) {

                        // ✅ UPDATE EXISTING
                        if (! empty($p['id'])) {

                            $existingParticipant = Participant::find($p['id']);

                            if ($existingParticipant) {

                                // 🔥 CHECK IF MATCHES EXIST FOR THIS TEAM
                                $hasMatches = \App\Models\MatchModel::where(function ($q) use ($existingParticipant) {
                                    $q->where('team_a_id', $existingParticipant->team_id)
                                        ->orWhere('team_b_id', $existingParticipant->team_id);
                                })->exists();

                                // ✅ ONLY UPDATE IF NO MATCHES EXIST
                                if (! $hasMatches) {
                                    $existingParticipant->update([
                                        'name'    => $p['name'] ?? null,
                                        'team_id' => $p['team_id'] ?? null,
                                    ]);
                                }
                            }

                        } else {

                            // ✅ ADD NEW ONLY
                            Participant::create([
                                'event_group_id' => $eventGroup->id,
                                'name'           => $p['name'] ?? null,
                                'team_id'        => $p['team_id'] ?? null,
                            ]);
                        }
                    }

                    // =========================================
                    // ✅ GENERATE FIXTURES ONLY FOR NEW GROUP
                    // =========================================
                    $hasMatchesAlready = \App\Models\MatchModel::where('event_group_id', $eventGroup->id)->exists();

                    if ($isNewGroup && ! $hasMatchesAlready) {

                        $participants = Participant::where('event_group_id', $eventGroup->id)->get();

                        // ✅ ROUND ROBIN
                        if ($eventGroup->format === 'round_robin') {

                            for ($i = 0; $i < count($participants); $i++) {
                                for ($j = $i + 1; $j < count($participants); $j++) {

                                    \App\Models\MatchModel::create([
                                        'tournament_id'  => $tournament->id,
                                        'event_group_id' => $eventGroup->id,
                                        'team_a_id'      => $participants[$i]->team_id,
                                        'team_a_name'    => $participants[$i]->name,
                                        'team_b_id'      => $participants[$j]->team_id,
                                        'team_b_name'    => $participants[$j]->name,
                                        'round'          => 'Round Robin',
                                        'round_index'    => 0,
                                        'match_index'    => 0,
                                        'status'         => 'scheduled',
                                    ]);
                                }
                            }
                        }

                        // ✅ KNOCKOUT
                        if ($eventGroup->format === 'knockout') {

                            $teams = $participants->values();

                            for ($i = 0; $i < count($teams); $i += 2) {

                                if (! isset($teams[$i + 1])) {
                                    break;
                                }

                                \App\Models\MatchModel::create([
                                    'tournament_id'  => $tournament->id,
                                    'event_group_id' => $eventGroup->id,
                                    'team_a_id'      => $teams[$i]->team_id,
                                    'team_a_name'    => $teams[$i]->name,
                                    'team_b_id'      => $teams[$i + 1]->team_id,
                                    'team_b_name'    => $teams[$i + 1]->name,
                                    'round'          => 'Round 1',
                                    'round_index'    => 0,
                                    'match_index'    => $i,
                                    'status'         => 'scheduled',
                                ]);
                            }
                        }
                    }

                    try {
                        $matches = \App\Models\MatchModel::where('event_group_id', $eventGroup->id)->get();

                        $standings = [];

                        foreach ($matches as $match) {

                            if ($match->status !== 'completed') {
                                continue;
                            }

                            // TEAM A
                            if (! isset($standings[$match->team_a_name])) {
                                $standings[$match->team_a_name] = [
                                    'played' => 0,
                                    'won'    => 0,
                                    'lost'   => 0,
                                    'points' => 0,
                                ];
                            }

                            // TEAM B
                            if (! isset($standings[$match->team_b_name])) {
                                $standings[$match->team_b_name] = [
                                    'played' => 0,
                                    'won'    => 0,
                                    'lost'   => 0,
                                    'points' => 0,
                                ];
                            }

                            $standings[$match->team_a_name]['played']++;
                            $standings[$match->team_b_name]['played']++;

                            if ($match->winner_name === $match->team_a_name) {
                                $standings[$match->team_a_name]['won']++;
                                $standings[$match->team_a_name]['points'] += 2;
                                $standings[$match->team_b_name]['lost']++;
                            } elseif ($match->winner_name === $match->team_b_name) {
                                $standings[$match->team_b_name]['won']++;
                                $standings[$match->team_b_name]['points'] += 2;
                                $standings[$match->team_a_name]['lost']++;
                            }
                        }

                        // 🔥 SAVE OR UPDATE STANDINGS TABLE
                        foreach ($standings as $teamName => $s) {

                            \App\Models\Standing::updateOrCreate(
                                [
                                    'event_group_id' => $eventGroup->id,
                                    'team_name'      => $teamName,
                                ],
                                [
                                    'played' => $s['played'],
                                    'won'    => $s['won'],
                                    'lost'   => $s['lost'],
                                    'points' => $s['points'],
                                ]
                            );
                        }

                    } catch (\Exception $e) {
                        \Log::error("Standings generation failed: " . $e->getMessage());
                    }
                }
            }
        }

        $tournament->load('eventGroups.participants', 'eventGroups.matches');

        return response()->json([
            'success' => true,
            'data'    => $tournament,
        ]);
    }

    public function uploadBanner(Request $request, $id)
    {
        $request->validate([
            'banner' => 'required|image|mimes:jpeg,png,jpg|max:5120',
        ]);

        $tournament = Tournament::findOrFail($id);

        // delete old banner
        if ($tournament->banner) {
            Storage::disk('public')->delete($tournament->banner);
        }

        $path = $request->file('banner')->store('tournaments', 'public');

        $tournament->banner = $path;
        $tournament->save();

        return response()->json([
            'success' => true,
            'url'     => Storage::url($path),
        ]);
    }

    public function destroy($id)
    {
        $tournament = Tournament::findOrFail($id);

        // ✅ SOFT DELETE
        $tournament->delete();

        return response()->json([
            'success' => true,
            'message' => 'Tournament deleted successfully',
        ]);
    }

    public function getSponsors($id)
    {
        $tournament = Tournament::findOrFail($id);

        return response()->json(
            $tournament->sponsors()->latest()->get()
        );
    }

    public function addSponsor(Request $request, $id)
    {
        $request->validate([
            'logo' => 'required|image|mimes:jpeg,png,jpg|max:5120',
            'name' => 'required|string|max:255',
            'url'  => 'nullable|string',
        ]);

        $tournament = Tournament::findOrFail($id);

        // store image
        $path = $request->file('logo')->store('sponsors', 'public');

        // save in DB
        $sponsor = TournamentSponsor::create([
            'tournament_id' => $tournament->id,
            'name'          => $request->name,
            'logo'          => $path,
            'url'           => $request->url,
        ]);

        return response()->json([
            'success' => true,
            'data'    => $sponsor,
        ], 201);
    }

    public function updateSponsor(Request $request, $id, $sponsorId)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'url'  => 'nullable|string',
        ]);

        $sponsor = TournamentSponsor::where('tournament_id', $id)
            ->findOrFail($sponsorId);

        $sponsor->update([
            'name' => $request->name,
            'url'  => $request->url,
        ]);

        return response()->json([
            'success' => true,
            'data'    => $sponsor,
        ]);
    }

    public function deleteSponsor($id, $sponsorId)
    {
        $sponsor = TournamentSponsor::where('tournament_id', $id)
            ->findOrFail($sponsorId);

        // delete image
        if ($sponsor->logo) {
            Storage::disk('public')->delete($sponsor->logo);
        }

        $sponsor->delete();

        return response()->json([
            'success' => true,
            'message' => 'Sponsor deleted',
        ]);
    }

    public function updateStatus(Request $request, $id)
    {
        try {
            \Log::info("UPDATE STATUS CALLED", ['id' => $id, 'status' => $request->status]);

            $tournament         = Tournament::findOrFail($id);
            $tournament->status = $request->status;
            $tournament->save();

            return response()->json([
                'success' => true,
                'status'  => $tournament->status,
            ]);
        } catch (\Exception $e) {
            \Log::error("UPDATE STATUS ERROR: " . $e->getMessage() . " | " . $e->getFile() . ":" . $e->getLine());
            return response()->json(['message' => $e->getMessage()], 500);
        }
    }

    public function generateFixtures($tournamentId)
    {
        // ✅ Step 1: Get valid teams only
        $teams = \App\Models\Team::where('tournament_id', $tournamentId)
            ->where('status', 'active')
            ->whereNull('deleted_at')
            ->where('locked', 1)
            ->where('is_published', 1)
            ->get();

        $totalTeams = $teams->count();

        if ($totalTeams < 2) {
            return response()->json([
                'message' => 'Not enough valid teams',
            ], 400);
        }

        $matches = [];

        // ✅ Step 2: Generate unique pairs
        for ($i = 0; $i < $totalTeams; $i++) {
            for ($j = $i + 1; $j < $totalTeams; $j++) {

                $teamA = $teams[$i]->id;
                $teamB = $teams[$j]->id;

                // ✅ Step 3: Prevent duplicates (important)
                $exists = \App\Models\MatchModel::where('tournament_id', $tournamentId)
                    ->where(function ($q) use ($teamA, $teamB) {
                        $q->where([
                            ['team_a_id', $teamA],
                            ['team_b_id', $teamB],
                        ])->orWhere([
                            ['team_a_id', $teamB],
                            ['team_b_id', $teamA],
                        ]);
                    })
                    ->exists();

                if (! $exists) {
                    $matches[] = [
                        'tournament_id' => $tournamentId,
                        'team_a_id'     => $teamA,
                        'team_b_id'     => $teamB,
                        'round'         => 1,
                        'status'        => 'scheduled',
                        'created_at'    => now(),
                        'updated_at'    => now(),
                    ];
                }
            }
        }

        // ✅ Step 4: Insert matches
        if (! empty($matches)) {
            \App\Models\MatchModel::insert($matches);
        }

        return response()->json([
            'message'         => 'Fixtures generated successfully',
            'matches_created' => count($matches),
            'teams_used'      => $totalTeams,
        ]);
    }

    public function updateMatch(Request $request, $id)
    {
        \Log::info($request->all());

        $match = MatchModel::findOrFail($id);

        if ($request->has('status')) {
            $match->status = strtolower(trim($request->status));
        }

        // ✅ date & time
        if ($request->has('match_date')) {
            $match->match_date = $request->match_date;
        }

        if ($request->has('match_time')) {
            $match->match_time = $request->match_time;
        }

        // ✅ court
        if ($request->has('court')) {
            $match->court = $request->court;
        }

        // 🔥 update team IDs if provided
        if ($request->has('team_a_id')) {
            $match->team_a_id = $request->team_a_id;
        }

        if ($request->has('team_b_id')) {
            $match->team_b_id = $request->team_b_id;
        }

        if ($request->has('team_a_name')) {
            $match->team_a_name = $request->team_a_name;
        }

        if ($request->has('team_b_name')) {
            $match->team_b_name = $request->team_b_name;
        }

        \Log::info("TEAM A ID: " . $match->team_a_id);
        \Log::info("TEAM B ID: " . $match->team_b_id);

        // ✅ MANUAL WINNER ONLY
        if ($request->has('winner_team_id')) {
            $match->winner_team_id = ! empty($request->winner_team_id)
                ? (int) $request->winner_team_id
                : null;
        }

// ✅ VERY IMPORTANT (PREVENT AUTO COMPLETE)
        if ($request->status === 'live' || $request->status === 'scheduled') {
            $match->winner_team_id = null;
        }

        // =====================================
        // 🔥 CONFLICT CHECK ONLY FOR SCHEDULED
        // =====================================

        if (
            strtolower($request->status ?? $match->status) === 'scheduled' &&
            $request->match_date &&
            $request->match_time &&
            $request->court
        ) {

            $newTime = \Carbon\Carbon::parse($request->match_date . ' ' . $request->match_time);

            $conflict = MatchModel::where('court', $request->court)
                ->where('id', '!=', $match->id)
                ->where('status', 'scheduled') // 🔥 ONLY SCHEDULED
                ->get()
                ->first(function ($m) use ($newTime) {

                    if (! $m->match_time) {
                        return false;
                    }

                    $existing = \Carbon\Carbon::parse($m->match_date . ' ' . $m->match_time);

                    return abs($existing->diffInMinutes($newTime)) <= 120;
                });

            if ($conflict) {
                return response()->json([
                    'message' => 'Court already booked (±2 hrs)',
                ], 409);
            }
        }

        $match->save();

        return response()->json([
            'success' => true,
            'data'    => $match,
        ]);
    }

    public function updateMatchStatus(Request $request, $id)
    {
        $match = \App\Models\MatchModel::findOrFail($id);

        $request->validate([
            'status' => 'required|in:scheduled,live,completed',
        ]);

        $currentStatus = $match->status;
        $newStatus     = $request->status;

        // ✅ valid transitions
        $validTransitions = [
            'scheduled' => ['live'],
            'live'      => ['completed'],
            'completed' => [],
        ];

        // ❌ block invalid transitions
        if (! in_array($newStatus, $validTransitions[$currentStatus])) {
            return response()->json([
                'message' => "Invalid transition: $currentStatus → $newStatus",
            ], 422);
        }

        // ✅ update
        $match->status = $newStatus;

        if ($newStatus === 'live') {
            $match->is_live = 1;
        }

        if ($newStatus === 'completed') {
            $match->is_live = 0;
        }

        $match->save();

        return response()->json([
            'message'  => 'Status updated',
            'match_id' => $match->id,
            'status'   => $match->status,
        ]);
    }

    public function createMatch(Request $request, $tournamentId)
    {
        $request->validate([
            'team_a_id' => 'required|exists:teams,id',
            'team_b_id' => 'required|exists:teams,id|different:team_a_id',
        ]);

        // ✅ check both teams belong to same tournament
        $teamA = \App\Models\Team::where('id', $request->team_a_id)
            ->where('tournament_id', $tournamentId)
            ->exists();

        $teamB = \App\Models\Team::where('id', $request->team_b_id)
            ->where('tournament_id', $tournamentId)
            ->exists();

        if (! $teamA || ! $teamB) {
            return response()->json([
                'message' => 'Teams must belong to the same tournament',
            ], 400);
        }

        // ✅ prevent duplicate match
        $exists = \App\Models\MatchModel::where('tournament_id', $tournamentId)
            ->where(function ($q) use ($request) {
                $q->where([
                    ['team_a_id', $request->team_a_id],
                    ['team_b_id', $request->team_b_id],
                ])->orWhere([
                    ['team_a_id', $request->team_b_id],
                    ['team_b_id', $request->team_a_id],
                ]);
            })
            ->exists();

        if ($exists) {
            return response()->json([
                'message' => 'Match already exists between these teams',
            ], 409);
        }

        // ✅ create match
        $match = \App\Models\MatchModel::create([
            'tournament_id' => $tournamentId,
            'team_a_id'     => $request->team_a_id,
            'team_b_id'     => $request->team_b_id,
            'round'         => 'manual',
            'status'        => 'scheduled',
        ]);

        return response()->json([
            'message' => 'Match created successfully',
            'match'   => $match,
        ], 201);
    }

    public function generateKnockout($tournamentId)
    {
        // ✅ Get valid teams
        $teams = \App\Models\Team::where('tournament_id', $tournamentId)
            ->where('status', 'active')
            ->whereNull('deleted_at')
            ->where('locked', 1)
            ->where('is_published', 1)
            ->pluck('id')
            ->toArray();

        $totalTeams = count($teams);

        // ❌ must be power of 2
        if ($totalTeams < 2 || ($totalTeams & ($totalTeams - 1)) !== 0) {
            return response()->json([
                'message' => 'Teams must be power of 2 (2,4,8,16...)',
            ], 400);
        }

        // 🔀 Shuffle teams (random pairing)
        shuffle($teams);

        $matches = [];
        $round   = 1;

        // ✅ Round 1 pairing
        for ($i = 0; $i < $totalTeams; $i += 2) {
            $matches[] = [
                'tournament_id' => $tournamentId,
                'team_a_id'     => $teams[$i],
                'team_b_id'     => $teams[$i + 1],
                'round'         => "round_$round",
                'status'        => 'scheduled',
                'created_at'    => now(),
                'updated_at'    => now(),
            ];
        }

        \App\Models\MatchModel::insert($matches);

        return response()->json([
            'message'         => 'Knockout Round 1 created',
            'matches_created' => count($matches),
            'teams_used'      => $totalTeams,
        ]);
    }

    public function completeMatch(Request $request, $id)
    {
        $match = \App\Models\MatchModel::findOrFail($id);

        $request->validate([
            'winner_team_id' => 'required|exists:teams,id',
        ]);

        // ❗ only allow if match is LIVE
        if ($match->status !== 'live') {
            return response()->json([
                'message' => 'Match must be live before completing',
            ], 400);
        }

        $winner = $request->winner_team_id;

        // ❗ winner must be one of the teams
        if ($winner != $match->team_a_id && $winner != $match->team_b_id) {
            return response()->json([
                'message' => 'Winner must be one of the match teams',
            ], 422);
        }

        // ✅ update
        $match->winner_team_id = $winner;
        $match->status         = 'completed';
        $match->is_live        = 0;
        $match->save();

        return response()->json([
            'message'        => 'Match completed',
            'winner_team_id' => $winner,
        ]);
    }

    public function generateNextRound($tournamentId)
    {
        return response()->json([
            'message' => 'Manual mode: next round disabled',
        ]);
    }

    public function getBracket($tournamentId)
    {
        $matches = \App\Models\MatchModel::where('tournament_id', $tournamentId)
            ->where('round', 'like', 'round_%')
            ->orderBy('round')
            ->get()
            ->map(function ($m) {

                // ✅ DO NOT OVERRIDE NAMES
                // just ensure fallback only

                if (empty($m->team_a_name)) {
                    $m->team_a_name = 'TBD';
                }

                if (empty($m->team_b_name)) {
                    $m->team_b_name = 'TBD';
                }

                return $m;
            })
            ->groupBy('round');

        return response()->json([
            'bracket' => $matches,
        ]);
    }

    public function uploadFixtureImage(Request $request, $id)
    {
        $tournament = Tournament::findOrFail($id);

        if ($request->hasFile('fixture_image')) {

            if ($tournament->fixture_image) {
                Storage::disk('public')->delete($tournament->fixture_image);
            }

            $path                      = $request->file('fixture_image')->store('fixtures', 'public');
            $tournament->fixture_image = $path;
            $tournament->save();

            return response()->json([
                'success' => true,
                'data'    => [
                    'fixture_image' => asset('storage/' . $path),
                ],
            ]);
        }

        return response()->json(['success' => false], 400);
    }
}
