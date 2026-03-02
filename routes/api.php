<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\HealthController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\SportController;
use App\Http\Controllers\EventController;
use App\Http\Controllers\PlayerController;
use App\Http\Controllers\VenueController;

Route::get('/health', [HealthController::class, 'index'])->middleware('jwt.auth');
Route::post('/login', [AuthController::class, 'login']);

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
    Route::put('/events/{id}', [EventController::class, 'update']);
    Route::delete('/events/{id}', [EventController::class, 'destroy']);
    Route::post('/events/{id}/restore', [EventController::class, 'restore']);
});

Route::middleware('jwt.auth')->group(function () {
    Route::get('/players', [PlayerController::class, 'index']);
    Route::post('/players', [PlayerController::class, 'store']);
    Route::get('/players/trashed', [PlayerController::class, 'trashed']);

    Route::get('/players/{id}', [PlayerController::class, 'show']);
    Route::put('/players/{id}', [PlayerController::class, 'update']);
    Route::delete('/players/{id}', [PlayerController::class, 'destroy']);
    Route::post('/players/{id}/restore', [PlayerController::class, 'restore']);
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


