<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Venue;

class VenueController extends Controller
{
    // get all venues
    public function index()
    {
        $venues = Venue::with('grounds')
            ->orderBy('id','desc')
            ->paginate(10);

        return response()->json($venues);
    }

    // create venue
    public function store(Request $request)
    {
        $venue = Venue::create([
            'venue_name' => $request->venue_name,
            'location' => $request->location,
            'total_courts' => $request->total_courts,
            'description' => $request->description,
            'is_active' => $request->is_active
        ]);

        if ($request->has('grounds')) {
            foreach ($request->grounds as $ground) {
                $venue->grounds()->create([
                    'ground_name' => $ground['ground_name'],
                    'ground_type' => $ground['ground_type'],
                    'court_count' => $ground['court_count']
                ]);
            }
        }

        return response()->json($venue->load('grounds'), 201);
    }

    // get single venue
    public function show($id)
    {
        return response()->json(
            Venue::with('grounds')->findOrFail($id)
        );
    }

    // update venue
    public function update(Request $request, $id)
    {
        $venue = Venue::findOrFail($id);

        $venue->update([
            'venue_name' => $request->venue_name,
            'location' => $request->location,
            'total_courts' => $request->total_courts,
            'description' => $request->description,
            'is_active' => $request->is_active
        ]);

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
