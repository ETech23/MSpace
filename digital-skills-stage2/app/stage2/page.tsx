import { Suspense } from "react";
import { Stage2Application } from "../../components/Stage2Application";

export default function Stage2Page() {
  return (
    <Suspense fallback={<Stage2Skeleton />}>
      <Stage2Application />
    </Suspense>
  );
}

function Stage2Skeleton() {
  return (
    <main className="mx-auto grid min-h-screen max-w-6xl gap-8 px-5 py-8 md:grid-cols-[0.9fr_1.1fr] md:px-8">
      <section className="glass-panel min-h-80 rounded-2xl p-6" />
      <section className="glass-panel rounded-2xl p-6">
        <div className="skeleton h-8 w-2/3" />
        <div className="mt-6 grid gap-4 sm:grid-cols-2">
          {Array.from({ length: 12 }).map((_, index) => (
            <div className="skeleton h-14" key={index} />
          ))}
        </div>
      </section>
    </main>
  );
}
