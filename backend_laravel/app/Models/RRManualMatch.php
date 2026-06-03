<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RRManualMatch extends Model
{
    protected $table = 'rr_manual_matches';

    protected $fillable = [
        'tournament_id',
        'event_group_id',

        'round',
        'round_order',
        'match_order',

        'team_a_name',
        'team_b_name',

        'team_a_id',
        'team_b_id',

        'match_date',
        'match_time',
        'court',

        'status',
        
        'winner_team_id',
    ];
}
