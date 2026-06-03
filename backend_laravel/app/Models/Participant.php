<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Participant extends Model
{
    protected $fillable = [
        'event_group_id',
        'team_id',
        'name',
        'email',
        'phone',
        'seed',
    ];

    public function team()
    {
        return $this->belongsTo(Team::class);
    }
}
