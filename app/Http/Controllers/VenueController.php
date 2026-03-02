<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Venue;

class VenueController extends Controller
{
    // get all venues
    public function index()
    {
        return response()->json(Venue::paginate(10));
    }

    // create venue
    public function store(Request $request)
    {
        $venue = Venue::create($request->all());

        return response()->json($venue, 201);
    }

    // get single venue
    public function show($id)
    {
        return response()->json(Venue::findorFail($id));
    }

    // update venue
    public function update(Request $request, $id)
    {
        $venue = Venue::findorFail($id);

        $venue->update($request->all());

        return response()->json($venue);
    }

    // delete venue
    public function destroy($id)
    {
        $venue = Venue::findorFail($id);

        $venue->delete();

        return response()->json(['message' => 'Venue deleted successfully']);
    }

    public function restore($id)
    {
        $venue = Venue::withTrashed()->findorFail($id);

        $venue->restore();

        return response()->json(['message' => 'Venue restored successfully']);
    }

    public function trashed()
    {
        return response()->json(Venue::onlyTrashed()->get());
    }
}
