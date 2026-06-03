<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up()
    {
        Schema::table('matches', function (Blueprint $table) {

            // Team structure
            if (! Schema::hasColumn('matches', 'team_a_id')) {
                $table->unsignedBigInteger('team_a_id')->nullable();
            }

            if (! Schema::hasColumn('matches', 'team_b_id')) {
                $table->unsignedBigInteger('team_b_id')->nullable();
            }

            if (! Schema::hasColumn('matches', 'team_a_name')) {
                $table->string('team_a_name')->nullable();
            }

            if (! Schema::hasColumn('matches', 'team_b_name')) {
                $table->string('team_b_name')->nullable();
            }

            // Match structure
            if (! Schema::hasColumn('matches', 'round')) {
                $table->string('round')->nullable();
            }

            if (! Schema::hasColumn('matches', 'match_number')) {
                $table->integer('match_number')->nullable();
            }

            if (! Schema::hasColumn('matches', 'round_index')) {
                $table->integer('round_index')->default(0);
            }

            if (! Schema::hasColumn('matches', 'match_index')) {
                $table->integer('match_index')->default(0);
            }

            // Date & Time
            if (! Schema::hasColumn('matches', 'match_date')) {
                $table->date('match_date')->nullable();
            }

            if (! Schema::hasColumn('matches', 'match_time')) {
                $table->time('match_time')->nullable();
            }

            // Venue / Court
            if (! Schema::hasColumn('matches', 'court')) {
                $table->string('court')->nullable();
            }

            // Scores
            if (! Schema::hasColumn('matches', 'sets')) {
                $table->json('sets')->nullable();
            }

            if (! Schema::hasColumn('matches', 'sets_won_a')) {
                $table->integer('sets_won_a')->default(0);
            }

            if (! Schema::hasColumn('matches', 'sets_won_b')) {
                $table->integer('sets_won_b')->default(0);
            }

            // Live
            if (! Schema::hasColumn('matches', 'is_live')) {
                $table->boolean('is_live')->default(false);
            }

            if (! Schema::hasColumn('matches', 'live_stream_url')) {
                $table->text('live_stream_url')->nullable();
            }

            // Status (if not exists)
            if (! Schema::hasColumn('matches', 'status')) {
                $table->enum('status', ['scheduled', 'live', 'completed', 'cancelled'])
                    ->default('scheduled');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        //
    }
};
