<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Tournament extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'name',
        'event_id',
        'sport_id',
        'format',
        'status',
        'banner',
        'min_players',
        'max_players',

        // 🔥 ADD THESE
        'venue_name',
        'venue_id',

        'start_date',
        'end_date',
        'registration_due_date',

        'contact_name',
        'contact_email',
        'contact_phone',

        'city',
        'state',
        'pin_code',

        'description',
    ];

    public function teams()
    {
        return $this->hasMany(Team::class);
    }

    public function eventGroups()
    {
        return $this->hasMany(EventGroup::class);
    }

    public function sponsors()
    {
        return $this->hasMany(TournamentSponsor::class);
    }
}
