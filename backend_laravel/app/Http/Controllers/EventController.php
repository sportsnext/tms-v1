<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Event;

class EventController extends Controller
{
    // get all events
    public function index()
    {
        return response()->json(
            Event::with('sport')->paginate(10)
        );
    }

    // create event
    public function store(Request $request)
    {
        $event = Event::create($request->all());

        return response()->json($event, 201);
    }

    // get single event
    public function show($id)
    {
        $event = Event::with('sport')->find($id);

        if (!$event) {
            return response()->json(['message' => 'Event not found'], 404);
        }

        return response()->json($event);
    }

    // update event
    public function update(Request $request, $id)
    {
        $event = Event::find($id);

        if (!$event) {
            return response()->json(['message' => 'Event not found'], 404);
        }

        $event->update($request->all());

        return response()->json($event);
    }

    // delete event
    public function destroy($id)
    {
        $event = Event::find($id);

        if (!$event) {
            return response()->json(['message' => 'Event not found'], 404);
        }

        $event->delete();

        return response()->json(['message' => 'Event deleted successfully']);
    }

    public function restore($id)
    {
        $event = Event::withTrashed()->findorFail($id);

        $event->restore();

        return response()->json(['message' => 'Event restored successfully']);
    }

    public function trashed()
    {
        return response()->json(Event::onlyTrashed()->get());
    }
}
