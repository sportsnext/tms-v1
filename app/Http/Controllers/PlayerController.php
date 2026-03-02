<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Player;

class PlayerController extends Controller
{
    // get all players
    public function index(Request $request)
    {
        $query = Player::with('event');

        if ($request->has('search')) {
            $query->where('full_name', 'LIKE', '%' . $request->search . '%');
        }

        return response()->json(
            $query->paginate(10)
        );
    }

    // create player
    public function store(Request $request)
    {
        $player = Player::create($request->all());

        return response()->json($player, 201);
    }

    // get single player
    public function show($id)
    {
        $player = Player::with('event')->find($id);

        if (!$player) {
            return response()->json(['message' => 'Player not found'], 404);
        }

        return response()->json($player);
    }

    // update player
    public function update(Request $request, $id)
    {
        $player = Player::find($id);

        if (!$player) {
            return response()->json(['message' => 'Player not found'], 404);
        }

        $player->update($request->all());

        return response()->json($player);
    }

    // delete player
    public function destroy($id)
    {
        $player = Player::find($id);

        if (!$player) {
            return response()->json(['message' => 'Player not found'], 404);
        }

        $player->delete();

        return response()->json(['message' => 'Player deleted successfully']);
    }

    public function restore($id)
    {
        $player = Player::withTrashed()->findorFail($id);

        $player->restore();

        return response()->json(['message' => 'Player restored successfully']);
    }

    public function trashed()
    {
        return response()->json(Player::onlyTrashed()->get());
    }
}
