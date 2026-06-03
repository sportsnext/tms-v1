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
        Schema::create('rr_manual_matches', function (Blueprint $table) {
            $table->id();

            $table->unsignedBigInteger('tournament_id');
            $table->unsignedBigInteger('event_group_id');

            $table->string('round');
            $table->integer('round_order');
            $table->integer('match_order');

            $table->string('team_a_name')->default('TBD');
            $table->string('team_b_name')->default('TBD');

            $table->unsignedBigInteger('team_a_id')->nullable();
            $table->unsignedBigInteger('team_b_id')->nullable();

            $table->date('match_date')->nullable();
            $table->time('match_time')->nullable();
            $table->string('court')->nullable();

            $table->string('status')->default('scheduled');
            $table->unsignedBigInteger('winner_team_id')->nullable();

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('rr_manual_matches');
    }
};
