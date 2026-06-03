<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Sport extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'sport_name',
        'description',
        'sport_type',
        'category',
        'icon',
        'scoring_type',
        'max_players_per_team',
        'sets',
        'games_per_set',
        'has_tiebreak',
        'tiebreak_at',
        'tiebreak_points',
        'tiebreak_diff',
        'golden_point',
        'notes'
    ];

    public function events()
    {
        return $this->hasMany(Event::class);
    }
}
