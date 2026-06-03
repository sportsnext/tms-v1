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
        Schema::create('matches', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tournament_id')->constrained()->cascadeOnDelete();

            $table->foreignId('team_a')->constrained('teams')->cascadeOnDelete();
            $table->foreignId('team_b')->constrained('teams')->cascadeOnDelete();

            $table->integer('round')->default(1);

            $table->enum('status', ['scheduled','live','completed'])->default('scheduled');

            $table->foreignId('venue_id')->nullable()->constrained()->nullOnDelete();

            $table->dateTime('date_time')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('matches');
    }
};
