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
        Schema::create('results', function (Blueprint $table) {
            $table->id();

            $table->unsignedBigInteger('fixture_id');

            $table->integer('home_score')->default(0);
            $table->integer('away_score')->default(0);

            $table->unsignedBigInteger('winner_team_id')->nullable();
            $table->string('result_type'); // WIN / DRAW

            $table->text('notes')->nullable();

            $table->integer('version')->default(1); // 🔒 concurrency

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('results');
    }
};
