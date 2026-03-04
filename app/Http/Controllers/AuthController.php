<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use app\Models\User;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $credentials = $request->only('email', 'password');

        if (!$token = auth('api')->attempt($credentials)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid email or password'
                ], 401);
        }

        return response()->json([
            'success' => true,
            'token' => $token,
            'user' => [
                'id' => auth('api')->user()->id,
                'name' => auth('api')->user()->name,
                'email' => auth('api')->user()->email,
                'role_id' => auth('api')->user()->role_id,
            ]
        ]);
    }

    public function register(Request $request)
    {
        $validatedData = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:6|confirmed',
        ]);

        $user = \App\Models\User::create([
            'name' => $validatedData['name'],
            'email' => $validatedData['email'],
            'password' => bcrypt($validatedData['password']),
            'role_id' => 5, 
        ]);

        return response()->json([
            'message' => 'Registration successful',
            'user' => $user
        ], 201);
    }

    public function me()
    {
        return response()->json([
            'success' => true,
            'user' => auth()->user()
        ]);
    }
}
