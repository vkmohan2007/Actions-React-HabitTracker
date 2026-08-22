import { addWeeks, eachDayOfInterval, endOfWeek, startOfWeek } from "date-fns";
import { HabitForm } from "./components/HabitForm";
import { HabitList } from "./components/HabitList";
import { Header } from "./components/Header";
import { HabitProvider } from "./context/HabitProvier";
import { useEffect, useState } from "react";

function App() {
  const [weekOffset, setWeekOffset] = useState(0);
  const week = addWeeks(new Date(), weekOffset)
  const visibleDates = eachDayOfInterval({
    start: startOfWeek(week, { weekStartsOn: 1 }),
    end: endOfWeek(week, { weekStartsOn: 1 }),
  });

  // when weekOffset changes a nw event listener will be added and the old
  // one will be removed.
  useEffect(() => {
    function handler() {
      console.log(weekOffset);
    }
    document.addEventListener("click", handler);

    return () => {
      document.removeEventListener("click", handler);
    };
  }, [weekOffset]);

  return (
    <div className="max-w-2xl mx-auto p-4 flex flex-col gap-2">
      <HabitProvider>
        <Header
          visibleDates={visibleDates}
          onNext={() => setWeekOffset(o => o + 1)}
          onPrev={() => {
            console.log(`the prev is hit: ${weekOffset}`);
            return setWeekOffset(o => o - 1);
          }}
        />
        <HabitForm />
        <HabitList visibleDates={visibleDates} />
      </HabitProvider>
    </div>
  );
}

export default App;
