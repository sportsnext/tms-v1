<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $credentials = $request->only('email', 'password');

        if (!$token = Auth::attempt($credentials)) {
            return response()->json([
                'message' => 'Invalid email or password'
                ], 401);
        }

        return response()->json([
            'message' => 'Login successful',
            'token' => $token,
            'auth_user' => [
                'id' => Auth::user()->id,
                'name' => Auth::user()->name,
                'email' => Auth::user()->email,
                'role_id' => Auth::user()->role_id,
            ]
        ]);
    }
}
