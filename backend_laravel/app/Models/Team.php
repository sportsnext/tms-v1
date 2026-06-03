<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Team extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'name',
        'sport',
        'max_players',
        'coach_name',
        'tournament_id',
        'status',
        'locked',
        'type',
    ];

    protected $casts = [
        'is_published' => 'integer',
        'is_locked'    => 'integer',
    ];

    public function tournament()
    {
        return $this->belongsTo(Tournament::class);
    }

    public function players()
    {
        return $this->belongsToMany(
            Player::class,
            'team_players', // pivot table
            'team_id',
            'player_id'
        );
    }
}
