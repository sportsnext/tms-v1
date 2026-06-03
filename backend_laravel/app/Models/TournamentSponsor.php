<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class TournamentSponsor extends Model
{
    use SoftDeletes;

    protected $fillable = [
    'tournament_id',
    'name',
    'logo',
    'url',
];
}
