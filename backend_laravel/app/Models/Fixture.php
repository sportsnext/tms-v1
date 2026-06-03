<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Fixture extends Model
{
    protected $fillable = [
        'tournament_id',
        'stage_id',
        'home_team_id',
        'away_team_id',
        'round',
        'match_date',
        'match_time',
        'venue',
        'status',
    ];
}
