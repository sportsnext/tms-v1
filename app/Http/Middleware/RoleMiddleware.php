<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RoleMiddleware
{
    public function handle(Request $request, Closure $next, $requiredRole): Response
    {
        $user = auth()->user();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized'
            ], 401);
        }

        if ($user->role_id > $requiredRole) {
            return response()->json([
                'success' => false,
                'message' => 'Forbidden - Role not allowed'
            ], 403);
        }

        return $next($request);
    }
}