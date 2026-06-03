<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class VenueGround extends Model
{
    protected $fillable = [
        'venue_id',
        'ground_name',
        'ground_type',
        'court_count'
    ];

    public function venue()
    {
        return $this->belongsTo(Venue::class);
    }
}
