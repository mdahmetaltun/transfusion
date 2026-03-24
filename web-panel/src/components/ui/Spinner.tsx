export function Spinner() {
  return (
    <div className="flex items-center justify-center w-full h-full min-h-48">
      <div className="w-9 h-9 border-[3px] border-gray-200 dark:border-gray-700 border-t-red-500 rounded-full animate-spin" />
    </div>
  );
}
