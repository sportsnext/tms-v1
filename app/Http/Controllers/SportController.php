<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Sport;

class SportController extends Controller
{
    // get all sports
    public function index()
    {
        return response()->json(Sport::paginate(10));
    }

    // create sport
    public function store(Request $request)
    {
        $sport = Sport::create($request->all());

        return response()->json([
            'message' => 'Sport created successfully',
            'sport' => $sport
        ], 201);
    }

    // get single sport
    public function show($id)
    {
        $sport = Sport::find($id);

        if (!$sport) {
            return response()->json(['message' => 'Sport not found'], 404);
        }

        return response()->json($sport);
    }

    // update sport
    public function update(Request $request, $id)
    {
        $sport = Sport::find($id);

        if (!$sport) {
            return response()->json(['message' => 'Sport not found'], 404);
        }

        $sport->update($request->all());

        return response()->json([
            'message' => 'Sport updated successfully',
            'sport' => $sport
        ]);
    }

    // delete sport
    public function destroy($id)
    {
        $sport = Sport::find($id);

        if (!$sport) {
            return response()->json(['message' => 'Sport not found'], 404);
        }

        $sport->delete();

        return response()->json(['message' => 'Sport deleted successfully']);
    }

    public function restore($id)
    {
        $sport = Sport::withTrashed()->findorFail($id);

        $sport->restore();

        return response()->json(['message' => 'Sport restored successfully']);
    }

    public function trashed()
    {
        return response()->json(Sport::onlyTrashed()->get());
    }
}
