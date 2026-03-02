<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Event extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'sport_id',
        'event_name',
        'start_date',
        'end_date',
        'location',
        'description',
        'status',
        'is_active' 
    ];

    public function sport()
    {
        return $this->belongsTo(Sport::class);
    }

    public function players()
    {
        return $this->hasMany(Player::class);
    }
}
