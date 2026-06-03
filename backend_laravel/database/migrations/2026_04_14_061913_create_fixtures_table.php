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
        Schema::create('fixtures', function (Blueprint $table) {
            $table->id();

            $table->unsignedBigInteger('tournament_id');
            $table->unsignedBigInteger('stage_id');

            $table->unsignedBigInteger('home_team_id');
            $table->unsignedBigInteger('away_team_id');

            $table->integer('round');

            $table->date('match_date')->nullable();
            $table->time('match_time')->nullable();

            $table->string('venue')->nullable();

            $table->string('status')->default('scheduled');

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('fixtures');
    }
};
