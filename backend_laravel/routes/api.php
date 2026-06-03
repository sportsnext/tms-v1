<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\EventController;
use App\Http\Controllers\FixtureController;
use App\Http\Controllers\HealthController;
use App\Http\Controllers\ManualMatchController;
use App\Http\Controllers\MatchController;
use App\Http\Controllers\PlayerController;
use App\Http\Controllers\ResultController;
use App\Http\Controllers\RRManualMatchController;
use App\Http\Controllers\SportController;
use App\Http\Controllers\StageController;
use App\Http\Controllers\StandingController;
use App\Http\Controllers\TeamController;
use App\Http\Controllers\TournamentController;
use App\Http\Controllers\VenueController;
use Illuminate\Support\Facades\Route;

Route::get('/health', [HealthController::class, 'index'])->middleware('jwt.auth');
Route::post('/login', [AuthController::class, 'login']);
Route::post('/register', [AuthController::class, 'register']);
Route::get('/me', [AuthController::class, 'me'])->middleware('jwt.auth');

Route::get('/dashboard', function () {
    return response()->json(['message' => 'Welcome to the dashboard']);
})->middleware('jwt.auth');

Route::middleware('jwt.auth')->group(function () {
    Route::get('/sports', [SportController::class, 'index']);
    Route::post('/sports', [SportController::class, 'store']);
    Route::get('/sports/trashed', [SportController::class, 'trashed']);

    Route::get('/sports/{id}', [SportController::class, 'show']);
    Route::put('/sports/{id}', [SportController::class, 'update']);
    Route::delete('/sports/{id}', [SportController::class, 'destroy']);
    Route::post('/sports/{id}/restore', [SportController::class, 'restore']);
});

Route::middleware('jwt.auth')->group(function () {
    Route::get('/events', [EventController::class, 'index']);
    Route::post('/events', [EventController::class, 'store']);
    Route::get('/events/trashed', [EventController::class, 'trashed']);

    Route::get('/events/{id}', [EventController::class, 'show']);
    Route::put('/events/{id}/update', [EventController::class, 'update']);
    Route::delete('/events/{id}', [EventController::class, 'destroy']);
    Route::post('/events/{id}/restore', [EventController::class, 'restore']);
});

Route::middleware('jwt.auth')->group(function () {
    Route::get('/players', [PlayerController::class, 'index']);
    Route::post('/players', [PlayerController::class, 'store']);
    Route::get('/players/trashed', [PlayerController::class, 'trashed']);

    Route::get('/players/duplicates', [PlayerController::class, 'getDuplicates']);
    Route::post('/players/merge-duplicates', [PlayerController::class, 'mergeDuplicates']);
    Route::post('/players/bulk-upload', [PlayerController::class, 'bulkUpload']);

    Route::get('/players/{id}', [PlayerController::class, 'show']);
    Route::put('/players/{id}', [PlayerController::class, 'update']);
    Route::delete('/players/{id}', [PlayerController::class, 'destroy']);
    Route::post('/players/{id}/restore', [PlayerController::class, 'restore']);
    Route::post('/players/{id}/toggle-active', [PlayerController::class, 'toggleActive']);
});

Route::middleware('jwt.auth')->group(function () {
    Route::get('/venues', [VenueController::class, 'index']);
    Route::post('/venues', [VenueController::class, 'store']);
    Route::get('/venues/trashed', [VenueController::class, 'trashed']);

    Route::get('/venues/{id}', [VenueController::class, 'show']);
    Route::put('/venues/{id}', [VenueController::class, 'update']);
    Route::delete('/venues/{id}', [VenueController::class, 'destroy']);
    Route::post('/venues/{id}/restore', [VenueController::class, 'restore']);
});

// Separate group - no {id} conflicts
Route::middleware('jwt.auth')->group(function () {
    Route::get('/teams/count', [TeamController::class, 'totalCount']);
    Route::get('/teams/trashed', [TeamController::class, 'trashed']);
});

Route::middleware('jwt.auth')->group(function () {
    Route::get('/tournaments/{id}/teams', [TeamController::class, 'index']);
    Route::get('/teams/{teamId}/players', [TeamController::class, 'teamPlayers']);
    Route::get('/teams/{teamId}/available-players', [TeamController::class, 'availablePlayers']);
    Route::get('/teams', [TeamController::class, 'allTeams']);
    Route::get('/tournaments', [TournamentController::class, 'index']);
    Route::get('/team-master', [TeamController::class, 'masterTeams']);
    Route::get('/master-individual-teams', [TeamController::class, 'masterIndividualTeams']);
    Route::get('/master-individual-only-teams', [TeamController::class, 'masterIndividualOnlyTeams']);

    Route::post('/tournaments/{id}/teams', [TeamController::class, 'store']);
    Route::post('/teams/{teamId}/players', [TeamController::class, 'assignPlayers']);
    Route::post('/teams/{teamId}/playing', [TeamController::class, 'setPlayingPlayers']);
    Route::post('/tournaments/{id}/publish', [TournamentController::class, 'publish']);
    Route::post('/teams/{id}/unlock', [TeamController::class, 'unlockTeam']);
    Route::post('/tournaments/{id}/unlock', [TournamentController::class, 'unlock']);
    Route::post('/players/transfer', [TeamController::class, 'transferPlayer']);

    Route::put('/teams/{id}', [TeamController::class, 'update']);
    Route::put('/teams/{id}/status', [TeamController::class, 'updateStatus']);
    Route::put('/teams/{id}/publish', [TeamController::class, 'togglePublish']);
    Route::delete('/teams/{id}', [TeamController::class, 'destroy']);
    Route::post('/teams/{id}/restore', [TeamController::class, 'restore']);
});

Route::middleware('jwt.auth')->group(function () {
    Route::get('/tournaments/{id}', [TournamentController::class, 'show']);

    Route::post('/tournaments', [TournamentController::class, 'store']);
    Route::put('/tournaments/{id}', [TournamentController::class, 'update']);

    Route::patch('/tournaments/{id}/publish', [TournamentController::class, 'publish']);
    Route::patch('/tournaments/{id}/unlock', [TournamentController::class, 'unlock']);
    Route::get('/tournaments', [TournamentController::class, 'index']);
    Route::delete('/tournaments/{id}', [TournamentController::class, 'destroy']);
    Route::patch('/tournaments/{id}/status', [TournamentController::class, 'updateStatus']);

    Route::patch('/matches/{id}', [MatchController::class, 'updateMatch']);

    Route::post('/tournaments/{id}/event-groups', [TournamentController::class, 'addEventGroup']);
    Route::post('/event-groups/{id}/participants', [TournamentController::class, 'addParticipant']);
    Route::post('/event-groups/{id}/matches', [TournamentController::class, 'storeMatches']);
    Route::post('/tournaments/{id}/publish', [TournamentController::class, 'publishTournament']);
    Route::post('/tournaments/{id}/banner', [TournamentController::class, 'uploadBanner']);
    Route::post('/tournaments/{id}/fixture-image', [TournamentController::class, 'uploadFixtureImage']);

    Route::get('/tournaments/{id}/sponsors', [TournamentController::class, 'getSponsors']);
    Route::post('/tournaments/{id}/sponsors', [TournamentController::class, 'addSponsor']);
    Route::put('/tournaments/{id}/sponsors/{sponsorId}', [TournamentController::class, 'updateSponsor']);
    Route::delete('/tournaments/{id}/sponsors/{sponsorId}', [TournamentController::class, 'deleteSponsor']);

    Route::post('/tournaments/{id}/generate-fixtures', [TournamentController::class, 'generateFixtures']);
    Route::patch('/matches/{id}/status', [TournamentController::class, 'updateMatchStatus']);
    Route::post('/tournaments/{id}/matches', [TournamentController::class, 'createMatch']);
    Route::post('/tournaments/{id}/knockout', [TournamentController::class, 'generateKnockout']);
    Route::patch('/matches/{id}/complete', [TournamentController::class, 'completeMatch']);
    // Route::post('/tournaments/{id}/next-round', [TournamentController::class, 'generateNextRound']);
    Route::get('/tournaments/{id}/bracket', [TournamentController::class, 'getBracket']);

    Route::post('/fixtures/{id}/update-teams', [TournamentController::class, 'updateFixtureTeams']);

    Route::delete('/matches/{id}', [MatchController::class, 'deleteMatch']);
});

Route::middleware('jwt.auth')->group(function () {

    // 🔥 MANUAL ONLY
    Route::post('/manual-matches', [ManualMatchController::class, 'store']);
    Route::get('/manual-matches/{eventGroupId}', [ManualMatchController::class, 'getByGroup']);
    Route::patch('/manual-matches/{id}', [ManualMatchController::class, 'update']);
    Route::delete('/manual-matches/{id}', [ManualMatchController::class, 'delete']);

    Route::post('/manual-matches/create-bracket', [ManualMatchController::class, 'createBracket']);
    Route::delete('/manual-matches/delete-all/{eventGroupId}', [ManualMatchController::class, 'deleteAll']);

});

Route::middleware('auth:api')->group(function () {
    Route::middleware('role:1')
        ->prefix('super-admin')
        ->group(function () {
            Route::get('/dashboard', function () {
                return response()->json([
                    'message' => 'Super Admin Access Granted',
                ]);
            });
        });

    Route::middleware('role:2')
        ->prefix('admin')
        ->group(function () {
            Route::get('/dashboard', function () {
                return response()->json([
                    'message' => 'Admin Access Granted',
                ]);
            });
        });

    Route::middleware('role:3')
        ->prefix('franchise/Organizer')
        ->group(function () {
            Route::get('/dashboard', function () {
                return response()->json([
                    'message' => 'Franchise/Organizer Access Granted',
                ]);
            });
        });

    Route::middleware('role:4')
        ->prefix('scorer')
        ->group(function () {
            Route::get('/dashboard', function () {
                return response()->json([
                    'message' => 'Scorer Access Granted',
                ]);
            });
        });

    Route::middleware('role:5')
        ->prefix('user')
        ->group(function () {
            Route::get('/dashboard', function () {
                return response()->json([
                    'message' => 'User Access Granted',
                ]);
            });
        });
});

Route::middleware('jwt.auth')->group(function () {

    Route::post('/tournaments/{id}/stages/{sid}/fixtures', [FixtureController::class, 'store']);
    Route::get('/tournaments/{id}/stages/{sid}/fixtures', [FixtureController::class, 'index']);
    Route::patch('/fixtures/{id}', [FixtureController::class, 'update']);

    Route::post('/fixtures/{id}/result', [ResultController::class, 'store']);
    Route::put('/fixtures/{id}/result', [ResultController::class, 'update']);
    Route::post('/stages/{sid}/lock', [StageController::class, 'lock']);

    Route::get('/standings/{eventGroupId}', [StandingController::class, 'index']);
    Route::post('/standings/{eventGroupId}/restore', [StandingController::class, 'restore']);
    Route::put('/standings/{id}', [StandingController::class, 'updateStanding']);

});

Route::middleware('jwt.auth')->group(function () {

    Route::post('/rr-manual', [RRManualMatchController::class, 'store']);
    Route::get('/rr-manual/{eventGroupId}', [RRManualMatchController::class, 'getByGroup']);
    Route::patch('/rr-manual/{id}', [RRManualMatchController::class, 'update']);
    Route::delete('/rr-manual/{eventGroupId}', [RRManualMatchController::class, 'deleteAll']);

    Route::post('/rr-manual/create-bracket', [RRManualMatchController::class, 'createBracket']);

});
