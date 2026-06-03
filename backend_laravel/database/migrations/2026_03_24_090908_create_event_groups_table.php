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
        Schema::create('event_groups', function (Blueprint $table) {
            $table->id();

            $table->foreignId('tournament_id')->constrained()->onDelete('cascade');

            $table->string('event_name')->nullable();
            $table->string('sport_name')->nullable();

            $table->enum('format', ['round_robin', 'knockout', 'custom']);
            $table->enum('participant_type', ['Team', 'Individual', 'Pair']);
            $table->enum('gender', ['Open', 'Men', 'Women', 'Mixed'])->default('Open');

            $table->integer('max_participants')->default(0);

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('event_groups');
    }
};
