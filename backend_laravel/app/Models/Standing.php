<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Standing extends Model
{
    protected $fillable = [
        'stage_id',
        'team_id',
        'played',
        'won',
        'draw',
        'lost',
        'gf',
        'ga',
        'gd',
        'sd',
        'points',
        'position',
        'h2h',
    ];
}
