<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Stage extends Model
{
    protected $fillable = [
        'tournament_id',
        'event_group_id',
        'name',
        'type',
        'status',
    ];

    public function eventGroup()
    {
        return $this->belongsTo(EventGroup::class, 'event_group_id');
    }
}
