import { createContext, useContext } from "react";

type Context = {
  habits: Habit[];
  addHabit: (name: string) => void;
  deleteHabit: (id: string) => void;
  toggleHabit: (id: string, date: Date) => void;
};

export type Habit = { id: string; name: string; completions: Date[] };

// context is null or context
export const HabitContext = createContext<null | Context>(null);
// a custom hook
export function useHabits() {
  const habitContext = useContext(HabitContext);
  if (habitContext == null) {
    throw Error("Null context");
  }
  return habitContext;
}
