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

            if (! Schema::hasColumn('matches', 'event_group_id')) {
                $table->foreignId('event_group_id')->nullable()->after('id');
            }

            if (! Schema::hasColumn('matches', 'round')) {
                $table->string('round')->nullable();
            }

            if (! Schema::hasColumn('matches', 'round_index')) {
                $table->integer('round_index')->default(0);
            }

            if (! Schema::hasColumn('matches', 'match_index')) {
                $table->integer('match_index')->default(0);
            }

            if (! Schema::hasColumn('matches', 'match_number')) {
                $table->integer('match_number')->nullable();
            }

            if (! Schema::hasColumn('matches', 'team_a_name')) {
                $table->string('team_a_name')->nullable();
            }

            if (! Schema::hasColumn('matches', 'team_b_name')) {
                $table->string('team_b_name')->nullable();
            }

            if (! Schema::hasColumn('matches', 'sets')) {
                $table->json('sets')->nullable();
            }

            if (! Schema::hasColumn('matches', 'sets_won_a')) {
                $table->integer('sets_won_a')->default(0);
            }

            if (! Schema::hasColumn('matches', 'sets_won_b')) {
                $table->integer('sets_won_b')->default(0);
            }

            if (! Schema::hasColumn('matches', 'is_live')) {
                $table->boolean('is_live')->default(false);
            }

            if (! Schema::hasColumn('matches', 'live_stream_url')) {
                $table->text('live_stream_url')->nullable();
            }
        });

        // Foreign key separate (safe)
        Schema::table('matches', function (Blueprint $table) {
            if (! Schema::hasColumn('matches', 'event_group_id')) {
                return;
            }

            $table->foreign('event_group_id')
                ->references('id')
                ->on('event_groups')
                ->onDelete('cascade');
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
