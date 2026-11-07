/// Where a rank requirement can realistically be worked on.
enum RequirementSetting {
  /// Knowledge or hands-on skills a leader can check at a meeting or on an
  /// outing, such as knots, first aid and discussions.
  skills,

  /// Needs an overnight campout.
  campout,

  /// Needs a hike or similar time outdoors.
  hike,

  /// Needs water, such as a swim or a boating outing.
  swim,

  /// Needs a service project.
  service,

  /// Needs any troop or patrol activity other than a regular meeting.
  outing,
}

class RankRequirement {
  final String rank;
  final String id;
  final String summary;
  final RequirementSetting setting;

  /// True when one event only counts toward the requirement, such as service
  /// hours or a total number of activities.
  final bool partial;

  const RankRequirement(
    this.rank,
    this.id,
    this.summary,
    this.setting, {
    this.partial = false,
  });

  String get displaySummary =>
      partial ? '$summary (this event counts toward it)' : summary;
}

/// Rank requirements that can be worked on at a troop event, as short
/// paraphrases. Check these against the current Scouts BSA requirements when
/// they are revised; the wording here is not the official text.
///
/// Numbering comes from the requirements published as effective January 2024
/// (Life requirement 4: August 2022). Requirements that can't happen at an
/// event are left out on purpose: Scoutmaster conferences, boards of review,
/// Scout spirit, parent exercises, tracked fitness plans and work done at home.
/// Star and Life only list their service hours.
const List<RankRequirement> rankRequirements = [
  // Scout
  RankRequirement('Scout', '1a', 'Scout Oath, Law, motto and slogan', RequirementSetting.skills),
  RankRequirement('Scout', '1b', 'Explain Scout spirit', RequirementSetting.skills),
  RankRequirement('Scout', '1c', 'Scout sign, salute and handshake', RequirementSetting.skills),
  RankRequirement('Scout', '1d', 'First Class badge and its meaning', RequirementSetting.skills),
  RankRequirement('Scout', '1e', 'Outdoor Code and Leave No Trace principles', RequirementSetting.skills),
  RankRequirement('Scout', '1f', 'Pledge of Allegiance and its meaning', RequirementSetting.skills),
  RankRequirement('Scout', '2a', 'How Scouts lead the troop', RequirementSetting.skills),
  RankRequirement('Scout', '2b', 'Four steps of advancement', RequirementSetting.skills),
  RankRequirement('Scout', '2c', 'Ranks and how they are earned', RequirementSetting.skills),
  RankRequirement('Scout', '2d', 'Merit badges and how they are earned', RequirementSetting.skills),
  RankRequirement('Scout', '3a', 'Explain the patrol method', RequirementSetting.skills),
  RankRequirement('Scout', '3b', 'Patrol name, emblem, flag and yell', RequirementSetting.skills),
  RankRequirement('Scout', '4a', 'Square knot, two half-hitches, taut-line hitch', RequirementSetting.skills),
  RankRequirement('Scout', '4b', 'Whip and fuse rope ends', RequirementSetting.skills),
  RankRequirement('Scout', '5', 'Safe pocketknife use', RequirementSetting.skills),

  // Tenderfoot
  RankRequirement('Tenderfoot', '1a', 'Show gear packed for an overnight', RequirementSetting.campout),
  RankRequirement('Tenderfoot', '1b', 'Spend a night in a tent you helped pitch', RequirementSetting.campout),
  RankRequirement('Tenderfoot', '1c', 'Explain using Outdoor Code and Leave No Trace on campouts', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '2a', 'Help prepare a meal on a campout', RequirementSetting.campout),
  RankRequirement('Tenderfoot', '2b', 'Safely clean cooking and eating items', RequirementSetting.campout),
  RankRequirement('Tenderfoot', '2c', 'Why a patrol eats together', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '3a', 'Practical use of the square knot', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '3b', 'Practical use of two half-hitches', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '3c', 'Practical use of the taut-line hitch', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '3d', 'Care and use of knife, saw and ax', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '4a', 'First aid for common minor injuries', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '4b', 'Identify hazardous plants and treat exposure', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '4c', 'Prevent the injuries in 4a and 4b', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '4d', 'Assemble a personal first-aid kit', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '5a', 'Use the buddy system on an outing', RequirementSetting.outing),
  RankRequirement('Tenderfoot', '5b', 'What to do if lost', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '5c', 'Safe hiking rules, day and night', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '5d', 'Hiking on durable surfaces, with examples', RequirementSetting.hike),
  RankRequirement('Tenderfoot', '6a', 'Record baseline fitness results', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '7a', 'Display, raise, lower and fold the flag', RequirementSetting.skills),
  RankRequirement('Tenderfoot', '7b', 'One hour of approved service', RequirementSetting.service, partial: true),
  RankRequirement('Tenderfoot', '8', 'Teach the square knot with Teaching EDGE', RequirementSetting.skills),

  // Second Class
  RankRequirement('Second Class', '1a', 'Five troop or patrol activities (3 outdoors, 2 overnight)', RequirementSetting.outing, partial: true),
  RankRequirement('Second Class', '1b', 'Leave No Trace principles from memory', RequirementSetting.skills),
  RankRequirement('Second Class', '1c', 'Choose a patrol campsite', RequirementSetting.campout),
  RankRequirement('Second Class', '2a', 'When a fire is appropriate', RequirementSetting.skills),
  RankRequirement('Second Class', '2b', 'Prepare tinder, kindling and fuel wood', RequirementSetting.campout),
  RankRequirement('Second Class', '2c', 'Build and extinguish a minimum-impact fire', RequirementSetting.campout),
  RankRequirement('Second Class', '2d', 'Choose, set up and light a stove safely', RequirementSetting.skills),
  RankRequirement('Second Class', '2e', 'Plan and cook a hot breakfast or lunch', RequirementSetting.campout),
  RankRequirement('Second Class', '2f', 'Sheet bend', RequirementSetting.skills),
  RankRequirement('Second Class', '2g', 'Bowline', RequirementSetting.skills),
  RankRequirement('Second Class', '3a', 'Compass, map orientation and map symbols', RequirementSetting.skills),
  RankRequirement('Second Class', '3b', '5-mile hike with map and compass', RequirementSetting.hike),
  RankRequirement('Second Class', '3c', 'Hike hazards and how to prevent them', RequirementSetting.hike),
  RankRequirement('Second Class', '3d', 'Find directions day and night without a compass', RequirementSetting.campout),
  RankRequirement('Second Class', '4', 'Identify 10 kinds of wild animals', RequirementSetting.hike, partial: true),
  RankRequirement('Second Class', '5a', 'Safe swim precautions', RequirementSetting.swim),
  RankRequirement('Second Class', '5b', 'BSA beginner test', RequirementSetting.swim),
  RankRequirement('Second Class', '5c', 'Reaching and throwing rescues', RequirementSetting.swim),
  RankRequirement('Second Class', '5d', 'When not to attempt a swimming rescue', RequirementSetting.swim),
  RankRequirement('Second Class', '6a', 'First aid for more serious injuries', RequirementSetting.skills),
  RankRequirement('Second Class', '6b', 'Stopped breathing, stroke, bleeding, poisoning', RequirementSetting.skills),
  RankRequirement('Second Class', '6c', 'Prevent the injuries in 6a and 6b', RequirementSetting.skills),
  RankRequirement('Second Class', '6d', 'Emergency response at home and in the backcountry', RequirementSetting.skills),
  RankRequirement('Second Class', '6e', 'Responding to a vehicle accident', RequirementSetting.skills),
  RankRequirement('Second Class', '8a', 'Take part in a flag ceremony', RequirementSetting.skills),
  RankRequirement('Second Class', '8b', 'Respect due the U.S. flag', RequirementSetting.skills),
  RankRequirement('Second Class', '8e', 'Two hours of approved service', RequirementSetting.service, partial: true),
  RankRequirement('Second Class', '9a', 'Three R\'s of personal safety', RequirementSetting.skills),
  RankRequirement('Second Class', '9b', 'Bullying and how to respond', RequirementSetting.skills),

  // First Class
  RankRequirement('First Class', '1a', '10 troop or patrol activities (6 outdoors, 3 overnight)', RequirementSetting.outing, partial: true),
  RankRequirement('First Class', '1b', 'Camping impacts on the environment', RequirementSetting.skills),
  RankRequirement('First Class', '2a', 'Help plan a campout menu', RequirementSetting.skills),
  RankRequirement('First Class', '2b', 'Budget and food list for three or more', RequirementSetting.skills),
  RankRequirement('First Class', '2c', 'Show cooking and serving gear', RequirementSetting.skills),
  RankRequirement('First Class', '2d', 'Safe food storage and trash disposal', RequirementSetting.skills),
  RankRequirement('First Class', '2e', 'Serve as cook on a campout', RequirementSetting.campout),
  RankRequirement('First Class', '3a', 'When to use lashings', RequirementSetting.skills),
  RankRequirement('First Class', '3b', 'Timber hitch and clove hitch', RequirementSetting.skills),
  RankRequirement('First Class', '3c', 'Square, shear and diagonal lashings', RequirementSetting.skills),
  RankRequirement('First Class', '3d', 'Lash a camp gadget or structure', RequirementSetting.campout),
  RankRequirement('First Class', '4a', 'One-mile orienteering course', RequirementSetting.hike),
  RankRequirement('First Class', '4b', 'Navigate with GPS or an electronic device', RequirementSetting.hike),
  RankRequirement('First Class', '5a', 'Identify 10 kinds of native plants', RequirementSetting.hike, partial: true),
  RankRequirement('First Class', '5b', 'Ways to get a weather forecast', RequirementSetting.skills),
  RankRequirement('First Class', '5c', 'Natural signs of hazardous weather', RequirementSetting.skills),
  RankRequirement('First Class', '5d', 'Planning for local extreme weather', RequirementSetting.skills),
  RankRequirement('First Class', '6a', 'BSA swimmer test', RequirementSetting.swim),
  RankRequirement('First Class', '6b', 'Safe trip afloat precautions', RequirementSetting.swim),
  RankRequirement('First Class', '6c', 'Parts of a boat and paddle', RequirementSetting.swim),
  RankRequirement('First Class', '6d', 'Body position in a watercraft', RequirementSetting.swim),
  RankRequirement('First Class', '6e', 'Line rescue as tender and rescuer', RequirementSetting.swim),
  RankRequirement('First Class', '7a', 'Bandage ankle, head, arm and collarbone', RequirementSetting.skills),
  RankRequirement('First Class', '7b', 'Move and transport an injured person', RequirementSetting.skills),
  RankRequirement('First Class', '7c', 'Heart attack signals and CPR steps', RequirementSetting.skills),
  RankRequirement('First Class', '7d', 'Utility hazards and emergencies', RequirementSetting.skills),
  RankRequirement('First Class', '7f', 'Getting potable water in an emergency', RequirementSetting.skills),
  RankRequirement('First Class', '9c', 'Track and reduce trash on an outing', RequirementSetting.outing),
  RankRequirement('First Class', '9d', 'Three hours of approved service', RequirementSetting.service, partial: true),

  // Star and Life
  RankRequirement('Star', '4', 'Six hours of approved service', RequirementSetting.service, partial: true),
  RankRequirement('Life', '4', 'Six hours of approved service (3 conservation)', RequirementSetting.service, partial: true),
];
