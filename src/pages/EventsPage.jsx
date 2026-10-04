import { EventCard } from "../components/events/EventCard";

const events = [
  {
    id: "fraser-games",
    title: "Fraser Games",
    date: "March 9–13, 2026",
    description:
      "What a week, Jags! Fraser Games was a massive success, bringing rivalry and collaboration together as teams scored points throughout the event. There was a fierce competition to see who could win it all during the many games throughout the school. Congratulations to our new Fraser Champions!",
    photo: "/images/Fraser-Games.jpg",
  },
  {
    id: "semi-formal",
    title: "Semi-Formal",
    date: "February 12, 2026",
    description:
      "This year, SAC delivered one of the most affordable semi-formals in Fraser's recent history. It was a night of great food, photos, and dancing. Thank you to everyone who came out and made this winter evening one to remember, full of love, laughter, and unforgettable moments.",
    photo: "/images/Semi-Formal.jpg",
  },
  {
    id: "snowy-cinema-food-drive",
    title: "Snowy Cinema x Winter Food Drive",
    date: "December 18, 2025",
    description:
      "The break was upon us, Jags! SAC and FAC teamed up for a surprise the student body didn't see coming. During P3, FAC ran a Student vs. Teacher volleyball spirit rally while SAC hosted a screening of The Grinch during P4, raising over $1,500 for charity in the spirit of the holidays. On top of that, SAC set a new record for our winter food drive, with homerooms competing to raise the most money and canned goods for our local food bank.",
    photo: "/images/Winter-Food-Drive.jpg",
  },
  {
    id: "twinkle-links",
    title: "Twinkle Links",
    date: "December, 2025",
    description:
      "All of a sudden, festive lights appeared across the school. Students searched for their names hidden among the display and submitted photos for a chance to win a raffle prize.",
    photo: "/images/Twinkle-Links.jpg",
  },
  {
    id: "tsms-workshop",
    title: "TSMS Workshop",
    date: "December 4, 2025",
    description:
      "SAC wrapped up the TSMS Grade 8 leadership workshop, finally bringing it back after a long break. We had a blast presenting, running activities, and celebrating with our future Jags.",
    photo: "/images/TSMS-Workshop.jpg",
  },
  {
    id: "mosaic-lunch",
    title: "Mosaic Lunch",
    date: "November 17, 2025",
    description:
      "The most exciting cultural event of the year, Mosaic Lunch brought the whole school together in the cafeteria for cultural booths and performances. It was a chance to experience the diversity, passion, and talent of our community through food, traditional crafts, and performances. Students also wore traditional attire to celebrate their heritage. Through this event, we raised over $1,000 for families in need through the Peel Winter Caring Program. Great job, Fraser!",
    photo: "/images/Mosaic-Lunch.jpg",
  },
  {
    id: "sac-retreat",
    title: "SAC Retreat",
    date: "November 17, 2025",
    description:
      "The council headed out to YMCA for a team-bonding retreat filled with tree-top trekking, archery, and plenty of good food — creating memories far more lasting than planned.",
    photo: "/images/SAC-Retreat.jpg",
  },
  {
    id: "fraser-fear-fest",
    title: "Fraser Fear Fest",
    date: "October 28, 2025",
    description:
      "Something spooky was going on — Fraser Fear Fest! SAC's brand-new Halloween event was our first attempt at a large-scale event early in the year, and it delivered: inflatables, a haunted maze, booths, movies, and snacks. Thank you to FAC, Visual Arts Club, AV Club, Arts Council, and Fraser Chefs for running booths and supporting the event. We welcomed over 360 attendees!",
    photo: "/images/Fear-Fest.jpg",
  },
  {
    id: "senior-sunrise",
    title: "Senior Sunrise",
    date: "October 7, 2025",
    description:
      "Thank you to all the seniors who joined us for Senior Sunrise. It was a great morning bringing most of the graduating class together one more time. Good luck with your post-secondary plans and studies!",
    photo: "/images/Senior-Sunrise.jpg",
  },
  {
    id: "club-promo-lunch",
    title: "Club Promo Lunch",
    date: "October 6–7, 2025",
    description:
      "Thank you to everyone who came out for Club Promo Lunch. We're proud to see every club show off their creativity and spirit this year.",
    photo: "/images/Club-Promo-Lunch.jpg",
  },
  {
    id: "terry-fox",
    title: "Terry Fox",
    date: "September 26, 2025",
    description:
      "For Terry Fox Day, SAC fired up a 'Heat for Hope' BBQ to support the food drive, while debuting our brand-new tap machines that will power most of our future events. Thanks to everyone's support, we raised $3,710.40 for the Terry Fox Foundation — way to go, Jags! SAC and FAC also teamed up for a hugely successful Terry Fox Walk, and wrapped it all up with a week-long Terry Fox trivia game, complete with five individual prizes.",
    photo: "/images/Terry-Fox.jpg",
  },
  {
    id: "grade9-orientation",
    title: "Grade 9 Orientation",
    date: "September 2, 2025",
    description:
      "SAC collaborated with FAC, PM, and Arts Council for an incredible welcome day for our incoming Grade 9s stepping into high school. From activities to great food and exciting presentations, it was all about building connections and making John Fraser feel like home.",
    photo: "/images/Grade-9-Orientation.jpg",
  },
];

export function EventsPage() {
  return (
    <div className="team-page">
      <div className="team-header">
        <h1 className="team-title">SAC Events</h1>
        <p className="team-subtitle">
          A look back at events SAC has hosted throughout the year.
        </p>
      </div>

      <div className="event-list">
        {events.map((event) => (
          <EventCard key={event.id} event={event} />
        ))}
      </div>
    </div>
  );
}