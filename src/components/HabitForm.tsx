import { useState, type SubmitEvent } from "react";
import Button from "./Button";
import { useHabits } from "../context/useHabit";

export function HabitForm() {
  const [name, setName] = useState<string>("");
  const { addHabit } = useHabits();

  function handleSubmit(e: SubmitEvent) {
    e.preventDefault();

    if (name.trim() === "") return;
    setName("");
    console.log(`inserted habit is: ${name}`);
    addHabit(name);
  }

  return (
    <form className="flex gap-2" onSubmit={handleSubmit}>
      <input
        value={name}
        onChange={(value) => setName(value.target.value)}
        className="flex-1 rounded-1g bg-zinc-800 px-4 py-2 outline-none focus-visible:ring-2 focus-visible:ring-violet-500"
        placeholder="New habit..."
      />
      <Button
        disabled={name.trim() === ""} // disabled when name is empty.
        className="rounded-lg px-4 py-2 font-meidum"
      >
        Add Habit
      </Button>
    </form>
  );
}
