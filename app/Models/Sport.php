<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Sport extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'sport_name', 
        'sport_type',
        'scoring_type',
        'max_players_per_team'
    ];

    public function events()
    {
        return $this->hasMany(Event::class);
    }
}
