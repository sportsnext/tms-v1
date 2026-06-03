<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class ManualMatch extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'tournament_id',
        'event_group_id',

        'team_a_id',
        'team_a_name',

        'team_b_id',
        'team_b_name',

        'match_date',
        'match_time',
        'court',

        'status',

        'winner_team_id',
        'winner_team_name',
        
        'round',
        'round_order',
        'match_order',
    ];
}
