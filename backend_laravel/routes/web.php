<?php

use Illuminate\Support\Facades\Route;

Route::get('/storage/{path}', function ($path) {

    $file = storage_path('app/public/' . $path);

    if (!file_exists($file)) {
        abort(404);
    }

    return response()->make(file_get_contents($file), 200, [
        'Content-Type' => mime_content_type($file),
        'Access-Control-Allow-Origin' => '*',
    ]);

})->where('path', '.*');