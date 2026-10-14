import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/models/whatsapp_flow_model.dart';

enum MetaFlowEndpointType {
  withoutEndpoint,
  withEndpoint,
}

class MetaFlowTemplate {
  final String id;
  final String title;
  final String description;
  final MetaFlowEndpointType endpointType;
  final String category; // Meta category: LEAD_GENERATION, SURVEY, CUSTOMER_SUPPORT, SIGN_UP, APPOINTMENT_BOOKING, OTHER
  final String flowTitle;
  final String ctaText;
  final String bodyText;
  final String? badgeText;
  final bool hasEndpointInfo;
  final IconData icon;
  final List<FlowFormField> fields;

  const MetaFlowTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.endpointType,
    required this.category,
    required this.flowTitle,
    required this.ctaText,
    required this.bodyText,
    this.badgeText,
    this.hasEndpointInfo = false,
    required this.icon,
    required this.fields,
  });

  /// Deep copy of fields to avoid mutating static template definitions
  List<FlowFormField> cloneFields() {
    return fields
        .map((f) => FlowFormField(
              name: f.name,
              label: f.label,
              type: f.type,
              required: f.required,
              options: List<String>.from(f.options),
            ))
        .toList();
  }
}

/// All 10 Official Meta WhatsApp Flow Templates
final List<MetaFlowTemplate> kAllMetaFlowTemplates = [
  // ─────────────────────────────────────────────────────────────
  // 1. Without Endpoint (Static Form Templates)
  // ─────────────────────────────────────────────────────────────
  MetaFlowTemplate(
    id: 'default',
    title: 'Default',
    description: 'Blank standard form to capture basic contact details or customize from scratch.',
    endpointType: MetaFlowEndpointType.withoutEndpoint,
    category: 'OTHER',
    flowTitle: 'Contact Information Form',
    ctaText: 'Open Form',
    bodyText: 'Please fill out your contact details below:',
    icon: Icons.assignment_outlined,
    fields: [
      FlowFormField(name: 'full_name', label: 'Full Name', type: 'text', required: true),
      FlowFormField(name: 'email', label: 'Email Address', type: 'email', required: true),
      FlowFormField(name: 'phone', label: 'Phone Number', type: 'phone', required: false),
    ],
  ),

  MetaFlowTemplate(
    id: 'purchase_interest',
    title: 'Collect purchase interest',
    description: 'Capture prospective buyer requirements, preferred product categories, budget, and timeline.',
    endpointType: MetaFlowEndpointType.withoutEndpoint,
    category: 'LEAD_GENERATION',
    flowTitle: 'Purchase Interest Inquiry',
    ctaText: 'Explore Offers',
    bodyText: 'Tell us what product or service you are interested in so we can provide personalized pricing:',
    badgeText: 'Lead Gen',
    icon: Icons.shopping_bag_outlined,
    fields: [
      FlowFormField(name: 'full_name', label: 'Your Full Name', type: 'text', required: true),
      FlowFormField(name: 'phone', label: 'WhatsApp Phone Number', type: 'phone', required: true),
      FlowFormField(
        name: 'product_category',
        label: 'Product / Service of Interest',
        type: 'dropdown',
        required: true,
        options: [
          'Electronics & Gadgets',
          'Fashion & Apparel',
          'Home & Lifestyle',
          'Software & Cloud Tools',
          'Professional Consulting',
        ],
      ),
      FlowFormField(
        name: 'budget_range',
        label: 'Estimated Budget',
        type: 'radio',
        required: true,
        options: [
          'Under \$100 / ₹5,000',
          '\$100 - \$500 / ₹5,000 - ₹25,000',
          '\$500 - \$1,000 / ₹25,000 - ₹75,000',
          '\$1,000+ / ₹75,000+',
        ],
      ),
      FlowFormField(
        name: 'timeline',
        label: 'When do you plan to purchase?',
        type: 'dropdown',
        required: true,
        options: [
          'Immediately (Within 24h)',
          'Within this week',
          'Within this month',
          'Just browsing / researching',
        ],
      ),
      FlowFormField(name: 'notes', label: 'Special Requirements / Details', type: 'textarea', required: false),
    ],
  ),

  MetaFlowTemplate(
    id: 'get_feedback',
    title: 'Get feedback',
    description: 'Collect customer satisfaction (CSAT) ratings, service quality reviews, and improvement suggestions.',
    endpointType: MetaFlowEndpointType.withoutEndpoint,
    category: 'SURVEY',
    flowTitle: 'Customer Experience Feedback',
    ctaText: 'Share Feedback',
    bodyText: 'Your feedback matters! Please rate your recent experience so we can continue improving:',
    badgeText: 'CSAT / NPS',
    icon: Icons.star_rate_rounded,
    fields: [
      FlowFormField(name: 'customer_name', label: 'Your Name (Optional)', type: 'text', required: false),
      FlowFormField(
        name: 'csat_rating',
        label: 'Overall Experience Rating',
        type: 'radio',
        required: true,
        options: [
          '⭐⭐⭐⭐⭐ 5 - Excellent',
          '⭐⭐⭐⭐ 4 - Good',
          '⭐⭐⭐ 3 - Average',
          '⭐⭐ 2 - Poor',
          '⭐ 1 - Very Poor',
        ],
      ),
      FlowFormField(
        name: 'highlight',
        label: 'What did you like most about our service?',
        type: 'dropdown',
        required: true,
        options: [
          'Fast Response Time',
          'Product Quality',
          'Friendly Support Staff',
          'Affordable Pricing',
          'Ease of Ordering',
        ],
      ),
      FlowFormField(name: 'feedback_text', label: 'What could we improve?', type: 'textarea', required: false),
      FlowFormField(
        name: 'recommend',
        label: 'Would you recommend us to a colleague or friend?',
        type: 'radio',
        required: true,
        options: ['Definitely Yes (10/10)', 'Likely (7-9)', 'Not Sure / Unlikely (1-6)'],
      ),
    ],
  ),

  MetaFlowTemplate(
    id: 'send_survey',
    title: 'Send a survey',
    description: 'Comprehensive multi-question survey for user habits, product research, and feature feedback.',
    endpointType: MetaFlowEndpointType.withoutEndpoint,
    category: 'SURVEY',
    flowTitle: 'User Experience & Product Survey',
    ctaText: 'Start Survey',
    bodyText: 'Take this quick 2-minute survey to help us tailor our platform to your needs:',
    badgeText: 'Multi-Question',
    icon: Icons.poll_outlined,
    fields: [
      FlowFormField(name: 'respondent_name', label: 'Participant Name (Optional)', type: 'text', required: false),
      FlowFormField(
        name: 'usage_frequency',
        label: 'How often do you interact with our platform?',
        type: 'radio',
        required: true,
        options: ['Daily', '2-3 times per week', 'A few times a month', 'First time today'],
      ),
      FlowFormField(
        name: 'primary_goal',
        label: 'Primary business goal',
        type: 'dropdown',
        required: true,
        options: [
          'Marketing Automation',
          'Lead Generation & Sales',
          'Customer Support & FAQ',
          'Team Collaboration',
        ],
      ),
      FlowFormField(
        name: 'favorite_tool',
        label: 'Most valuable feature to you',
        type: 'dropdown',
        required: true,
        options: [
          'Interactive WhatsApp Flows',
          'Bulk Broadcast Campaigns',
          'Automated Chatbots',
          'Analytics & Reporting',
        ],
      ),
      FlowFormField(
        name: 'retention_score',
        label: 'How likely are you to keep using our service?',
        type: 'radio',
        required: true,
        options: ['Extremely Likely', 'Somewhat Likely', 'Neutral', 'Unlikely'],
      ),
      FlowFormField(name: 'feature_wish', label: 'What feature or tool should we build next?', type: 'textarea', required: false),
    ],
  ),

  MetaFlowTemplate(
    id: 'customer_support',
    title: 'Customer support',
    description: 'Direct support ticket creation with issue categories, urgency levels, and callback channels.',
    endpointType: MetaFlowEndpointType.withoutEndpoint,
    category: 'CUSTOMER_SUPPORT',
    flowTitle: 'Support Ticket & Assistance',
    ctaText: 'Contact Support',
    bodyText: 'Experiencing an issue? Submit your query and our team will get in touch shortly:',
    badgeText: 'Helpdesk',
    icon: Icons.support_agent_rounded,
    fields: [
      FlowFormField(name: 'customer_name', label: 'Full Name', type: 'text', required: true),
      FlowFormField(name: 'contact_info', label: 'Email Address or Phone Number', type: 'text', required: true),
      FlowFormField(
        name: 'issue_type',
        label: 'Issue Category',
        type: 'dropdown',
        required: true,
        options: [
          'Account & Login Problem',
          'Billing & Payment',
          'Order & Delivery Status',
          'Technical Glitch / Bug',
          'General Question',
        ],
      ),
      FlowFormField(
        name: 'priority_level',
        label: 'Urgency Level',
        type: 'radio',
        required: true,
        options: [
          'Low - Minor Query',
          'Medium - Standard Support',
          'High - Critical / Urgent Issue',
        ],
      ),
      FlowFormField(name: 'order_ref', label: 'Order / Account ID (Optional)', type: 'text', required: false),
      FlowFormField(name: 'issue_description', label: 'Describe the problem in detail', type: 'textarea', required: true),
      FlowFormField(
        name: 'callback_method',
        label: 'Preferred Callback Channel',
        type: 'dropdown',
        required: true,
        options: ['WhatsApp Message', 'Phone Call', 'Email Response'],
      ),
    ],
  ),

  // ─────────────────────────────────────────────────────────────
  // 2. With Endpoint (Dynamic Data Exchange Templates)
  // ─────────────────────────────────────────────────────────────
  MetaFlowTemplate(
    id: 'loan_credit_card',
    title: 'Get leads for a pre-approved loan/credit card',
    description: 'Financial qualification flow collecting income, employment status, loan amount, and credit bureau consent.',
    endpointType: MetaFlowEndpointType.withEndpoint,
    category: 'LEAD_GENERATION',
    flowTitle: 'Pre-Approved Loan & Card Eligibility',
    ctaText: 'Check Eligibility',
    bodyText: 'Check your pre-approved loan or credit card eligibility in under 60 seconds:',
    badgeText: 'Endpoint template available',
    hasEndpointInfo: true,
    icon: Icons.credit_card_rounded,
    fields: [
      FlowFormField(name: 'full_legal_name', label: 'Full Legal Name (as on ID)', type: 'text', required: true),
      FlowFormField(name: 'mobile_number', label: 'Registered Mobile Number', type: 'phone', required: true),
      FlowFormField(
        name: 'employment_type',
        label: 'Employment Status',
        type: 'radio',
        required: true,
        options: [
          'Salaried Professional',
          'Self-Employed / Business Owner',
          'Freelancer / Gig Worker',
        ],
      ),
      FlowFormField(
        name: 'monthly_income',
        label: 'Monthly In-Hand Income',
        type: 'dropdown',
        required: true,
        options: [
          'Under \$2,000 / ₹25,000',
          '\$2,000 - \$5,000 / ₹25k - ₹50k',
          '\$5,000 - \$10,000 / ₹50k - ₹1L',
          '\$10,000+ / ₹1L+',
        ],
      ),
      FlowFormField(
        name: 'requested_amount',
        label: 'Requested Loan / Credit Limit',
        type: 'dropdown',
        required: true,
        options: [
          '\$1,000 - \$5,000 / ₹25k - ₹50k',
          '\$5,000 - \$15,000 / ₹50k - ₹1.5L',
          '\$15,000 - \$50,000 / ₹1.5L - ₹5L',
          '\$50,000+ / ₹5L+',
        ],
      ),
      FlowFormField(
        name: 'repayment_tenure',
        label: 'Preferred Repayment Tenure',
        type: 'radio',
        required: true,
        options: ['6 Months', '12 Months', '24 Months', '36+ Months'],
      ),
      FlowFormField(name: 'city_residence', label: 'Current City', type: 'text', required: true),
      FlowFormField(
        name: 'credit_check_consent',
        label: 'Credit Bureau Verification Consent',
        type: 'radio',
        required: true,
        options: [
          'I authorize credit bureau verification and agree to T&C',
          'I decline',
        ],
      ),
    ],
  ),

  MetaFlowTemplate(
    id: 'insurance_quote',
    title: 'Provide insurance quote',
    description: 'Calculate customized premium estimates for health, vehicle, life, or travel insurance policies.',
    endpointType: MetaFlowEndpointType.withEndpoint,
    category: 'LEAD_GENERATION',
    flowTitle: 'Instant Insurance Quotation',
    ctaText: 'Get Instant Quote',
    bodyText: 'Fill in your insurance parameters below to receive an instant premium quotation:',
    badgeText: 'Endpoint template available',
    hasEndpointInfo: true,
    icon: Icons.health_and_safety_outlined,
    fields: [
      FlowFormField(name: 'proposer_name', label: 'Policyholder Full Name', type: 'text', required: true),
      FlowFormField(name: 'contact_phone', label: 'Contact Phone Number', type: 'phone', required: true),
      FlowFormField(
        name: 'policy_type',
        label: 'Insurance Category',
        type: 'radio',
        required: true,
        options: [
          'Health & Family Mediclaim',
          'Motor / Vehicle Insurance',
          'Term Life Insurance',
          'International Travel Insurance',
        ],
      ),
      FlowFormField(
        name: 'insured_age_group',
        label: 'Age Group of Primary Insured',
        type: 'dropdown',
        required: true,
        options: [
          '18 - 25 Years',
          '26 - 35 Years',
          '36 - 45 Years',
          '46 - 60 Years',
          '60+ Senior Citizen',
        ],
      ),
      FlowFormField(
        name: 'sum_insured',
        label: 'Desired Coverage (Sum Insured)',
        type: 'dropdown',
        required: true,
        options: [
          '\$50,000 / ₹5 Lakhs',
          '\$100,000 / ₹10 Lakhs',
          '\$250,000 / ₹25 Lakhs',
          '\$500,000+ / ₹50 Lakhs+',
        ],
      ),
      FlowFormField(
        name: 'medical_history',
        label: 'Pre-existing Medical Conditions / Past Claims',
        type: 'radio',
        required: true,
        options: [
          'None / Clean Record',
          'Minor Medical Conditions',
          'Existing Claimed Policy',
        ],
      ),
      FlowFormField(name: 'pincode', label: 'Residential Postal Code / Pincode', type: 'text', required: true),
    ],
  ),

  MetaFlowTemplate(
    id: 'personalised_offer',
    title: 'Capture interest for a personalised offer',
    description: 'Profile prospects to match them with tailored discount tiers, campaign perks, and VIP rewards.',
    endpointType: MetaFlowEndpointType.withEndpoint,
    category: 'LEAD_GENERATION',
    flowTitle: 'Personalized VIP Offer & Deals',
    ctaText: 'Claim Offer',
    bodyText: 'Unlock exclusive personalized discounts and VIP membership perks tailored to your profile:',
    badgeText: 'Endpoint template available',
    hasEndpointInfo: true,
    icon: Icons.local_offer_outlined,
    fields: [
      FlowFormField(name: 'customer_name', label: 'Your Full Name', type: 'text', required: true),
      FlowFormField(name: 'whatsapp_number', label: 'WhatsApp Mobile Number', type: 'phone', required: true),
      FlowFormField(
        name: 'selected_offer',
        label: 'Choose Special Offer Tier',
        type: 'dropdown',
        required: true,
        options: [
          'Early Bird Discount (30% Off)',
          'VIP Annual Membership Pass',
          'Product Bundle Upgrade',
          'Free 1-on-1 Strategy Session',
        ],
      ),
      FlowFormField(
        name: 'decision_driver',
        label: 'What matters most in your choice?',
        type: 'radio',
        required: true,
        options: [
          'Maximum Savings & Lowest Price',
          'Premium Quality & VIP Perks',
          'Fast Implementation & Support',
        ],
      ),
      FlowFormField(
        name: 'contact_time',
        label: 'Best Time to Receive Offer Details',
        type: 'dropdown',
        required: true,
        options: [
          'Send Immediately via WhatsApp',
          'Morning (9 AM - 12 PM)',
          'Afternoon (12 PM - 5 PM)',
          'Evening (5 PM - 8 PM)',
        ],
      ),
      FlowFormField(name: 'referral_code', label: 'Promo / Referral Code (Optional)', type: 'text', required: false),
    ],
  ),

  MetaFlowTemplate(
    id: 'account_signup',
    title: 'Account sign-in/sign-up',
    description: 'Seamless customer onboarding and sign-up with tier selection, regional info, and terms acceptance.',
    endpointType: MetaFlowEndpointType.withEndpoint,
    category: 'SIGN_UP',
    flowTitle: 'Account Registration & Onboarding',
    ctaText: 'Create Account',
    bodyText: 'Register your new account in seconds to get started with full access:',
    badgeText: 'Endpoint template available',
    hasEndpointInfo: true,
    icon: Icons.how_to_reg_outlined,
    fields: [
      FlowFormField(name: 'full_name', label: 'Full Legal Name', type: 'text', required: true),
      FlowFormField(name: 'business_email', label: 'Work Email Address', type: 'email', required: true),
      FlowFormField(name: 'phone_number', label: 'Mobile Phone Number', type: 'phone', required: true),
      FlowFormField(
        name: 'account_type',
        label: 'Account Category',
        type: 'radio',
        required: true,
        options: [
          'Individual / Personal',
          'Business / Enterprise',
          'Developer / Agency',
        ],
      ),
      FlowFormField(name: 'country_region', label: 'Country / Region', type: 'text', required: true),
      FlowFormField(
        name: 'discovery_source',
        label: 'How did you discover us?',
        type: 'dropdown',
        required: true,
        options: [
          'Google Search',
          'LinkedIn / Social Media',
          'Colleague / Friend Referral',
          'Webinar / Event',
          'Other',
        ],
      ),
      FlowFormField(
        name: 'terms_consent',
        label: 'Acceptance of Terms & Policies',
        type: 'radio',
        required: true,
        options: [
          'I agree to the Terms of Service & Privacy Policy',
          'I do not agree',
        ],
      ),
    ],
  ),

  MetaFlowTemplate(
    id: 'appointment_booking',
    title: 'Appointment booking',
    description: 'Consultation and slot scheduling with meeting format, specialist selection, and date/time pickers.',
    endpointType: MetaFlowEndpointType.withEndpoint,
    category: 'APPOINTMENT_BOOKING',
    flowTitle: 'Appointment & Consultation Booking',
    ctaText: 'Book Appointment',
    bodyText: 'Reserve your consultation with our specialist at a date and time that suits your schedule:',
    badgeText: 'Endpoint template available',
    hasEndpointInfo: true,
    icon: Icons.calendar_month_outlined,
    fields: [
      FlowFormField(name: 'client_name', label: 'Your Full Name', type: 'text', required: true),
      FlowFormField(name: 'phone_number', label: 'WhatsApp Contact Number', type: 'phone', required: true),
      FlowFormField(
        name: 'meeting_type',
        label: 'Meeting Format',
        type: 'radio',
        required: true,
        options: [
          'Virtual Video Call (Zoom/Google Meet)',
          'In-Person Office Visit',
          'Phone Call',
        ],
      ),
      FlowFormField(
        name: 'specialist_dept',
        label: 'Department / Service Needed',
        type: 'dropdown',
        required: true,
        options: [
          'General Consultation',
          'Product Demo & Walkthrough',
          'Technical Implementation',
          'Business Strategy Review',
        ],
      ),
      FlowFormField(name: 'preferred_date', label: 'Preferred Date', type: 'date', required: true),
      FlowFormField(
        name: 'time_slot',
        label: 'Preferred Time Window',
        type: 'dropdown',
        required: true,
        options: [
          'Morning (09:00 AM - 12:00 PM)',
          'Afternoon (12:00 PM - 03:00 PM)',
          'Evening (03:00 PM - 06:00 PM)',
        ],
      ),
      FlowFormField(name: 'special_notes', label: 'Special Requests / Consultation Agenda', type: 'textarea', required: false),
    ],
  ),
];

List<MetaFlowTemplate> get kMetaTemplatesWithoutEndpoint =>
    kAllMetaFlowTemplates.where((t) => t.endpointType == MetaFlowEndpointType.withoutEndpoint).toList();

List<MetaFlowTemplate> get kMetaTemplatesWithEndpoint =>
    kAllMetaFlowTemplates.where((t) => t.endpointType == MetaFlowEndpointType.withEndpoint).toList();
