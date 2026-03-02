<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Player extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'event_id',
        'full_name',
        'gender',
        'date_of_birth',
        'age_group',
        'skill_level',
        'phone',
        'email',
        'is_active'
    ];

    public function event()
    {
        return $this->belongsTo(Event::class);
    }
}
