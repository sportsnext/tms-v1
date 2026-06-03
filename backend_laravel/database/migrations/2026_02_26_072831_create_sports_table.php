<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('sports', function (Blueprint $table) {
            $table->id();

            $table->string('sport_name');
            $table->text('description')->nullable();

            $table->string('sport_type');
            $table->string('category')->nullable();
            $table->string('icon')->nullable();

            $table->string('scoring_type')->nullable();
            $table->integer('max_players_per_team')->nullable();

            $table->integer('sets')->default(3);
            $table->integer('games_per_set')->default(6);

            $table->boolean('has_tiebreak')->default(true);
            $table->integer('tiebreak_at')->default(6);
            $table->integer('tiebreak_points')->default(7);
            $table->integer('tiebreak_diff')->default(2);

            $table->boolean('golden_point')->default(true);

            $table->text('notes')->nullable();

            $table->timestamps();
            $table->softdeletes();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sports');
    }
};
