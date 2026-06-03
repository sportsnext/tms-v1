<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MatchModel extends Model
{
    protected $table = 'matches';

    protected $fillable = [
        'tournament_id',
        'event_group_id',

        'team_a_id',
        'team_b_id',
        'team_a_name',
        'team_b_name',

        "winner_team_id",
        "winner_team_name",

        'home_score',
        'away_score',

        'round',
        'match_number',
        'round_index',
        'match_index',
        'match_date',
        'match_time',
        'court',
        'status',
    ];
}
