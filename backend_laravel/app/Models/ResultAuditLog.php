<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ResultAuditLog extends Model
{
    protected $fillable = [
        'fixture_id',
        'old_data',
        'new_data',
        'updated_by',
    ];
}
