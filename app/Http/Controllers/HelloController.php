<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class HelloController extends Controller
{
    /**
     * Return a hello world JSON response
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function hello()
    {
        return response()->json([
            'message' => 'Hello World!',
            'status' => 'success',
            'timestamp' => now()->toISOString()
        ]);
    }
}
