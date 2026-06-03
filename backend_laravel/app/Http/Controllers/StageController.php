<?php
namespace App\Http\Controllers;

use App\Models\AuditLog;
use Illuminate\Support\Facades\Auth;

class StageController extends Controller
{
    public function lock($stageId)
    {
        $stage = \App\Models\Stage::findOrFail($stageId);

        $old = $stage->toArray();

        $stage->update([
            'status' => 'locked',
        ]);

        AuditLog::create([
            'user_id'     => Auth::id(),
            'action'      => 'LOCK_STAGE',
            'entity_type' => 'stage',
            'entity_id'   => $stage->id,
            'old_data'    => $old,
            'new_data'    => $stage->toArray(),
        ]);

        return response()->json([
            "success" => true,
            "message" => "Stage locked",
        ]);
    }
}
