<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Result extends Model
{
    protected $fillable = [
        'fixture_id',
        'home_score',
        'away_score',
        'winner_team_id',
        'result_type',
        'notes',
        'version',
    ];
}
