import { parseISO } from "date-fns";
import { useState, type SetStateAction, type Dispatch, useEffect } from "react";

export function useLocaLStorage<T>(
  key: string,
  initialValue: T,
): [T, Dispatch<SetStateAction<T>>] {
  // function runs at the first time of render
  const [storedValue, setStoredValue] = useState<T>(() => {
    try {
      const item = localStorage.getItem(key);
      if (item == null) return initialValue;
      return JSON.parse(item, dateReviver);
    } catch {
      return initialValue;
    }
  });

  // run a side effect due to change in state
  useEffect(() => {
    localStorage.setItem(key, JSON.stringify(storedValue));
  }, [storedValue, key]);

  return [storedValue, setStoredValue];
}

function dateReviver(_key: string, value: unknown) {
  // check if the date is converted to string or not.
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}T/.test(value)) {
    return parseISO(value);
  }
  return value;
}
