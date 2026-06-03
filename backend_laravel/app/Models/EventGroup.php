<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class EventGroup extends Model
{
    protected $fillable = [
        'tournament_id',
        'event_name',
        'sport_name',
        'format',
        'participant_type',
        'gender',
        'max_participants',
    ];

    public function participants()
    {
        return $this->hasMany(Participant::class);
    }

    public function matches()
    {
        return $this->hasMany(MatchModel::class, 'event_group_id');
    }

    public function stage()
    {
        return $this->hasOne(Stage::class, 'event_group_id');
    }
}
