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

            // Add team A & B
            if (! Schema::hasColumn('matches', 'team_a_id')) {
                $table->unsignedBigInteger('team_a_id')->nullable();
            }

            if (! Schema::hasColumn('matches', 'team_b_id')) {
                $table->unsignedBigInteger('team_b_id')->nullable();
            }

            // Optional FK
            $table->foreign('team_a_id')->references('id')->on('teams')->nullOnDelete();
            $table->foreign('team_b_id')->references('id')->on('teams')->nullOnDelete();

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
