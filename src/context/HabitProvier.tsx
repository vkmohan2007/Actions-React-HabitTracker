import { type ReactNode } from "react";
import { HabitContext, type Habit } from "./useHabit";
import { isSameDay } from "date-fns";
import { useLocaLStorage } from "../hooks/useLocalStorage";

type HabitProviderProps = {
  children: ReactNode;
};

export function HabitProvider({ children }: HabitProviderProps) {
  const [habits, setHabits] = useLocaLStorage<Habit[]>("Habits", []);

  function addHabit(name: string) {
    setHabits((curr: Habit[]) => [
      ...curr,
      {
        id: crypto.randomUUID(),
        name: name,
        completions: [],
      },
    ]);
  }

  function deleteHabit(id: string) {
    setHabits((curr: Habit[]) => curr.filter((h) => h.id !== id));
  }

  function toggleHabit(id: string, date: Date) {
    setHabits((curr: Habit[]) =>
      curr.map((h: Habit) => {
        if (h.id !== id) return h;
        // if I have already done is.
        const alreadyDone = h.completions.some((c) => isSameDay(c, date));
        // if I have done it, remove it.
        const completions = alreadyDone
          ? h.completions.filter((c) => !isSameDay(c, date))
          : [...h.completions, date];
        return { ...h, completions };
      }),
    );
  }
  return (
    <HabitContext value={{ habits, addHabit, toggleHabit, deleteHabit }}>
      {children}
    </HabitContext>
  );
}
