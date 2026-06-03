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
        Schema::create('standings_snapshots', function (Blueprint $table) {
            $table->id();

            $table->unsignedBigInteger('stage_id'); // ✅ FIXED

            $table->json('data'); // full standings snapshot

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('standings_snapshots');
    }
};
