/* ============================================================
   PROJECT: Instagram User Engagement & Growth Analysis - SQL Solutions
   AUTHOR: Sunny
   ============================================================ */
   
   USE ig_clone;

/* =======================================================================================================================================================
   Q1. Are there any tables with duplicate or missing null values? If so, how would you handle them?
========================================================================================================================================================== */
-- Check NULL usernames
SELECT 
    SUM(username IS NULL) AS null_usernames
FROM users AS u;

-- Check NULL ids
SELECT 
    SUM(id IS NULL) AS null_id
FROM users AS u;

-- Check NULL image_url and NULL user_id in photos
SELECT 
    SUM(image_url IS NULL) AS null_image_urls,
    SUM(user_id IS NULL) AS null_user_ids
FROM photos AS p;

-- Check NULL user_id and NULL photo_id in likes
SELECT 
    SUM(user_id IS NULL) AS null_like_user_ids,
    SUM(photo_id IS NULL) AS null_like_photo_ids
FROM likes AS l;

-- Check duplicate usernames
SELECT 
    username AS duplicate_username,
    COUNT(*) AS cnt
FROM users AS u
GROUP BY username
HAVING COUNT(*) > 1;

-- Check duplicate like relationships
SELECT 
    user_id AS dup_user_id,
    photo_id AS dup_photo_id,
    COUNT(*) AS cnt
FROM likes AS l
GROUP BY user_id, photo_id
HAVING COUNT(*) > 1;



/* =======================================================================================================================================================
   Q2. What is the distribution of user activity levels (e.g., number of posts, likes, comments) across the user base?
========================================================================================================================================================== */

WITH posts AS (
  SELECT user_id, COUNT(*) AS post_count
  FROM photos
  GROUP BY user_id
),
likes AS (
  SELECT user_id, COUNT(*) AS like_count
  FROM likes
  GROUP BY user_id
),
comments AS (
  SELECT user_id, COUNT(*) AS comment_count
  FROM comments
  GROUP BY user_id
),
user_activity AS (
  SELECT
    u.id,
    u.username,
    COALESCE(p.post_count,0)    AS post_count,
    COALESCE(l.like_count,0)    AS like_count,
    COALESCE(c.comment_count,0) AS comment_count,
    COALESCE(p.post_count,0) + COALESCE(l.like_count,0) + COALESCE(c.comment_count,0) AS total_activity
  FROM users u
  LEFT JOIN posts p ON u.id = p.user_id
  LEFT JOIN likes l ON u.id = l.user_id
  LEFT JOIN comments c ON u.id = c.user_id
)
SELECT
  CASE
    WHEN total_activity = 0 THEN 'Inactive'
    WHEN total_activity BETWEEN 1 AND 5 THEN 'Low'
    WHEN total_activity BETWEEN 6 AND 20 THEN 'Medium'
    ELSE 'High'
  END AS activity_level,
  COUNT(*) AS user_count
FROM user_activity
GROUP BY activity_level
ORDER BY FIELD(activity_level, 'Inactive','Low','Medium','High');


/* =======================================================================================================================================================
   Q3. Calculate the average number of tags per post (photo_tags and photos tables).
========================================================================================================================================================== */

WITH tag_count AS (
    SELECT 
        p.id AS photo_id,
        COUNT(pt.tag_id) AS tags_on_photo
    FROM photos p
    LEFT JOIN photo_tags pt ON p.id = pt.photo_id
    GROUP BY p.id
)
SELECT 
    ROUND(AVG(tags_on_photo)) AS avg_tags_per_post
FROM tag_count;


/* =======================================================================================================================================================
   Q4. Identify the top users with the highest engagement rates (likes, comments) on their posts and rank them.
========================================================================================================================================================== */

WITH posts AS (                       -- total posts per user
  SELECT user_id, COUNT(*) AS total_posts
  FROM photos
  GROUP BY user_id
),
likes_received AS (                   -- likes received on photos grouped by photo-owner (user)
  SELECT p.user_id AS user_id, COUNT(*) AS likes_received
  FROM photos p
  JOIN likes l ON p.id = l.photo_id
  GROUP BY p.user_id
),
comments_received AS (                  -- comments received on photos grouped by photo-owner (user)
  SELECT p.user_id AS user_id, COUNT(*) AS comments_received
  FROM photos p
  JOIN comments c ON p.id = c.photo_id
  GROUP BY p.user_id
),
engagement AS (
  SELECT
    u.id AS user_id,
    u.username,
    COALESCE(p.total_posts, 0) AS total_posts,
    COALESCE(l.likes_received, 0) AS likes_received,
    COALESCE(c.comments_received, 0) AS comments_received,
    (COALESCE(l.likes_received, 0) + COALESCE(c.comments_received, 0)) AS total_engagement,
    CASE
      WHEN COALESCE(p.total_posts, 0) = 0 THEN 0
      ELSE ROUND( (COALESCE(l.likes_received, 0) + COALESCE(c.comments_received, 0))
                 / COALESCE(p.total_posts, 0), 2)
    END AS avg_engagement_per_post
  FROM users u
  LEFT JOIN posts p ON u.id = p.user_id
  LEFT JOIN likes_received l ON u.id = l.user_id
  LEFT JOIN comments_received c ON u.id = c.user_id
)

SELECT
  user_id, username, total_posts, likes_received, comments_received, total_engagement, avg_engagement_per_post,
  RANK() OVER (ORDER BY avg_engagement_per_post DESC, total_engagement DESC) AS rank_by_avg
FROM engagement
ORDER BY rank_by_avg
LIMIT 10;   -- top 10


/* =======================================================================================================================================================
   Q5. Which users have the highest number of followers and followings?
========================================================================================================================================================== */

-- Top User by Followers
WITH follower_data AS (
    SELECT 
        u.id,
        u.username,
        COUNT(f.follower_id) AS follower_count,
        DENSE_RANK() OVER (ORDER BY COUNT(f.follower_id) DESC) AS rk
    FROM users u
    LEFT JOIN follows f ON u.id = f.followee_id
    GROUP BY u.id, u.username
)
SELECT 
    id, username, follower_count
FROM follower_data
WHERE rk = 1;

-- Top User by Followings
WITH following_data AS (
    SELECT 
        u.id,
        u.username,
        COUNT(f.followee_id) AS following_count,
        DENSE_RANK() OVER (ORDER BY COUNT(f.followee_id) DESC) AS rk
    FROM users u
    LEFT JOIN follows f ON u.id = f.follower_id
    GROUP BY u.id, u.username
)
SELECT 
    id, username, following_count
FROM following_data
WHERE rk = 1;



/* =======================================================================================================================================================
   Q6. Calculate the average engagement rate (likes, comments) per post for each user.
========================================================================================================================================================== */

WITH 
-- Count posts per user
post_count AS (
    SELECT user_id, COUNT(*) AS total_posts
    FROM photos
    GROUP BY user_id
),
-- Count likes received on each user’s posts
likes_received AS (
    SELECT p.user_id, COUNT(*) AS total_likes_received
    FROM photos p
    LEFT JOIN likes l ON p.id = l.photo_id
    GROUP BY p.user_id
),
-- Count comments received on each user’s posts
comments_received AS (
    SELECT p.user_id, COUNT(*) AS total_comments_received
    FROM photos p
    LEFT JOIN comments c ON p.id = c.photo_id
    GROUP BY p.user_id
)
-- Final engagement calculation per user
SELECT
    u.id AS user_id,
    u.username,
    COALESCE(pc.total_posts, 0) AS total_posts,
    COALESCE(l.total_likes_received, 0) AS likes_received,
    COALESCE(cm.total_comments_received, 0) AS comments_received,
    (COALESCE(l.total_likes_received, 0) + COALESCE(cm.total_comments_received, 0)) 
        AS total_engagement,
    CASE 
        WHEN COALESCE(pc.total_posts, 0) = 0 THEN 0
        ELSE ROUND(
            (COALESCE(l.total_likes_received, 0) + COALESCE(cm.total_comments_received, 0)) 
            / pc.total_posts, 2)
    END AS avg_engagement_per_post
FROM users u
LEFT JOIN post_count pc ON u.id = pc.user_id
LEFT JOIN likes_received l ON u.id = l.user_id
LEFT JOIN comments_received cm ON u.id = cm.user_id
ORDER BY avg_engagement_per_post DESC;


/* =======================================================================================================================================================
   Q7. Get the list of users who have never liked any post (users and likes tables)
========================================================================================================================================================== */

SELECT
  u.id   AS user_id,
  u.username
FROM users u
WHERE NOT EXISTS (
    SELECT 1
    FROM likes l
    WHERE l.user_id = u.id
)
ORDER BY u.id;


/* =======================================================================================================================================================
   Q8. How can you leverage user-generated content (posts, hashtags, photo tags) to create more personalized and engaging ad campaigns?
========================================================================================================================================================== */

-- Identify most-used hashtags
SELECT t.tag_name, COUNT(pt.photo_id) AS usage_count
FROM tags t
JOIN photo_tags pt ON t.id = pt.tag_id
GROUP BY t.tag_name
ORDER BY usage_count DESC
LIMIT 10;

-- Find posts with highest engagement (likes + comments)
SELECT p.id, u.username,
       COUNT(DISTINCT l.user_id) AS likes,
       COUNT(DISTINCT c.id) AS comments,
       (COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)) AS total_engagement
FROM photos p
LEFT JOIN likes l ON p.id = l.photo_id
LEFT JOIN comments c ON p.id = c.photo_id
JOIN users u ON u.id = p.user_id
GROUP BY p.id, u.username
ORDER BY total_engagement DESC
LIMIT 10;

-- Identify frequently tagged users (potential micro-influencers)
SELECT u.username, COUNT(pt.tag_id) AS total_tags
FROM users u
JOIN photos p ON u.id = p.user_id
LEFT JOIN photo_tags pt ON p.id = pt.photo_id
GROUP BY u.username
ORDER BY total_tags DESC
LIMIT 10;

/* =======================================================================================================================================================
   Q9. Are there any correlations between user activity levels and specific content types (e.g., photos, videos, reels)? 
       How can this information guide content creation and curation strategies? 
========================================================================================================================================================== */

SELECT 
    t.tag_name AS content_type,
    COUNT(DISTINCT p.id) AS total_photos,
    COUNT(l.photo_id) AS total_likes,
    COUNT(c.id) AS total_comments
FROM tags t
JOIN photo_tags pt ON t.id = pt.tag_id
JOIN photos p ON pt.photo_id = p.id
LEFT JOIN likes l ON p.id = l.photo_id
LEFT JOIN comments c ON p.id = c.photo_id
GROUP BY t.tag_name
ORDER BY total_likes DESC;







/* =======================================================================================================================================================
   Q10. Calculate the total number of likes, comments, and photo tags for each user.
========================================================================================================================================================== */

WITH
likes_received AS (
  SELECT p.user_id,
         COUNT(*) AS total_likes
  FROM photos p
  JOIN likes l ON p.id = l.photo_id
  GROUP BY p.user_id
),
comments_received AS (
  SELECT p.user_id,
         COUNT(*) AS total_comments
  FROM photos p
  JOIN comments c ON p.id = c.photo_id
  GROUP BY p.user_id
),
tags_count AS (
  SELECT p.user_id,
         COUNT(*) AS total_tags
  FROM photos p
  JOIN photo_tags pt ON p.id = pt.photo_id
  GROUP BY p.user_id
)
SELECT
  u.id         AS user_id,
  u.username,
  COALESCE(lr.total_likes, 0)    AS total_likes_received,
  COALESCE(cr.total_comments, 0) AS total_comments_received,
  COALESCE(tr.total_tags, 0)     AS total_tags
FROM users u
LEFT JOIN likes_received lr    ON u.id = lr.user_id
LEFT JOIN comments_received cr ON u.id = cr.user_id
LEFT JOIN tags_count tr     ON u.id = tr.user_id
ORDER BY total_likes_received DESC;


/* =======================================================================================================================================================
   Q11. Rank users based on their total engagement (likes, comments, shares) over a month.
========================================================================================================================================================== */

WITH
-- Count likes received per user in the last 1 month
likes_month AS (
    SELECT 
        p.user_id,
        COUNT(*) AS likes_count
    FROM likes l
    JOIN photos p ON l.photo_id = p.id      
    WHERE l.created_at >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
    GROUP BY p.user_id
),
-- Count comments received per user in the last 1 month
comments_month AS (
    SELECT 
        p.user_id,
        COUNT(*) AS comments_count
    FROM comments c
    JOIN photos p ON c.photo_id = p.id      -- map comment to the photo owner
    WHERE c.created_at >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
    GROUP BY p.user_id
),
-- Combine total engagement
engagement_month AS (
    SELECT
        u.id AS user_id,
        u.username,
        COALESCE(lm.likes_count, 0)    AS likes_in_month,
        COALESCE(cm.comments_count, 0) AS comments_in_month,
        (COALESCE(lm.likes_count, 0) + COALESCE(cm.comments_count, 0)) 
            AS total_engagement_in_month
    FROM users u
    LEFT JOIN likes_month lm      ON u.id = lm.user_id
    LEFT JOIN comments_month cm   ON u.id = cm.user_id
)
-- Final ranking
SELECT
    user_id, username, likes_in_month, comments_in_month, total_engagement_in_month,
    DENSE_RANK() OVER (ORDER BY total_engagement_in_month DESC) AS engagement_rank
FROM engagement_month
WHERE total_engagement_in_month > 0        
ORDER BY engagement_rank, total_engagement_in_month DESC;


/* =======================================================================================================================================================
   Q12. Retrieve the hashtags that have been used in posts with the highest average number of likes. 
        Use a CTE to calculate the average likes for each hashtag first.
========================================================================================================================================================== */

WITH
photo_likes AS (
  SELECT
    p.id AS photo_id,
    COUNT(l.photo_id) AS likes_count
  FROM photos p
  LEFT JOIN likes l
    ON p.id = l.photo_id
  GROUP BY p.id
),
tag_photo_likes AS (
  SELECT
    t.id      AS tag_id,
    t.tag_name,
    pl.photo_id,
    pl.likes_count
  FROM photo_likes pl
  JOIN photo_tags pt ON pl.photo_id = pt.photo_id
  JOIN tags t ON pt.tag_id = t.id
),
tag_avg AS (
  SELECT
    tag_id,
    tag_name,
    COUNT(*) AS photo_count,        -- number of photos using this tag
    SUM(likes_count) AS total_likes,
    ROUND(AVG(likes_count), 2) AS avg_likes   -- average likes per photo for this tag
  FROM tag_photo_likes
  GROUP BY tag_id, tag_name
)
SELECT
  tag_name,
  photo_count,
  total_likes,
  avg_likes
FROM tag_avg
ORDER BY avg_likes DESC, total_likes DESC
LIMIT 10;   


/* =======================================================================================================================================================
   Q13. Retrieve the users who have started following someone after being followed by that person
========================================================================================================================================================== */


WITH follow_events AS (
    SELECT 
        f1.follower_id AS user_id,           -- user who followed back
        f1.followee_id AS followed_user_id,  -- the person they followed
        f2.created_at AS followed_by_time,   -- when that person followed them
        f1.created_at AS followed_back_time  -- when they followed back
    FROM follows f1
    JOIN follows f2 
      ON f1.follower_id = f2.followee_id     -- A followed B
     AND f1.followee_id = f2.follower_id     -- B followed A
    WHERE f1.created_at > f2.created_at       
)
SELECT
    fe.user_id,
    u1.username AS user_username,
    fe.followed_user_id,
    u2.username AS followed_username,
    fe.followed_by_time,
    fe.followed_back_time
FROM follow_events fe
JOIN users u1 ON fe.user_id = u1.id
JOIN users u2 ON fe.followed_user_id = u2.id
ORDER BY fe.followed_back_time DESC;




/*Subjective Questions*/



/* =======================================================================================================================================================
   Q1. Based on user engagement and activity levels, which users would you consider the most loyal or valuable? How would you reward or incentivize these users?
========================================================================================================================================================== */

WITH -- Posts created by each user
user_posts AS (
    SELECT 
        user_id, COUNT(*) AS total_posts
    FROM photos
    GROUP BY user_id
),
-- Likes GIVEN by each user
likes_given AS (
    SELECT 
        user_id, COUNT(*) AS likes_given
    FROM likes
    GROUP BY user_id
),
-- Comments GIVEN by each user
comments_given AS (
    SELECT 
        user_id, COUNT(*) AS comments_given
    FROM comments
    GROUP BY user_id
),
-- Likes RECEIVED on user posts
likes_received AS (
    SELECT 
        p.user_id,COUNT(*) AS likes_received
    FROM photos p
    LEFT JOIN likes l ON p.id = l.photo_id
    GROUP BY p.user_id
),
-- Comments RECEIVED on user posts
comments_received AS (
    SELECT 
        p.user_id, COUNT(*) AS comments_received
    FROM photos p
    LEFT JOIN comments c ON p.id = c.photo_id
    GROUP BY p.user_id
),
-- TAGS RECEIVED on user posts
tags_received AS (
    SELECT 
        p.user_id, COUNT(*) AS tags_received
    FROM photos p
    LEFT JOIN photo_tags pt ON p.id = pt.photo_id
    GROUP BY p.user_id
),
-- Combine all metrics
combined AS (
    SELECT 
        u.id AS user_id, u.username,

        COALESCE(up.total_posts, 0) AS posts_created,
        COALESCE(lg.likes_given, 0) AS likes_given,
        COALESCE(cg.comments_given, 0) AS comments_given,

        COALESCE(lr.likes_received, 0) AS likes_received,
        COALESCE(cr.comments_received, 0) AS comments_received,
        COALESCE(tr.tags_received, 0) AS tags_received,

        -- Activity Score (user actions)
        (COALESCE(up.total_posts, 0) 
        + COALESCE(lg.likes_given, 0) 
        + COALESCE(cg.comments_given, 0)) AS activity_score,

        -- Engagement Score (attention received)
        (COALESCE(lr.likes_received, 0) 
        + COALESCE(cr.comments_received, 0) 
        + COALESCE(tr.tags_received, 0)) AS engagement_score
    FROM users u
    LEFT JOIN user_posts up ON u.id = up.user_id
    LEFT JOIN likes_given lg ON u.id = lg.user_id
    LEFT JOIN comments_given cg ON u.id = cg.user_id
    LEFT JOIN likes_received lr ON u.id = lr.user_id
    LEFT JOIN comments_received cr ON u.id = cr.user_id
    LEFT JOIN tags_received tr ON u.id = tr.user_id

)
-- FINAL CLASSIFICATION
SELECT
    *,
    CASE
        WHEN engagement_score > 200 THEN 'Highly Engaged'
        WHEN engagement_score BETWEEN 50 AND 200 THEN 'Moderately Engaged'
        WHEN engagement_score BETWEEN 1 AND 49 THEN 'Low Engagement'
        ELSE 'No Engagement'
    END AS engagement_level,

    CASE
        WHEN activity_score > 20 THEN 'Highly Active'
        WHEN activity_score BETWEEN 6 AND 20 THEN 'Moderately Active'
        WHEN activity_score BETWEEN 1 AND 5 THEN 'Low Active'
        ELSE 'Inactive'
    END AS activity_level
FROM combined
ORDER BY engagement_score DESC, activity_score DESC
LIMIT 10;



/* =======================================================================================================================================================
   Q2. For inactive users, what strategies would you recommend to re-engage them and encourage them to start posting or engaging again?
========================================================================================================================================================== */


WITH user_engagement AS (
    SELECT 
        u.id AS user_id,
        COUNT(DISTINCT p.id) AS posts_count,
        COUNT(DISTINCT l.photo_id) AS likes_count,
        COUNT(DISTINCT c.id) AS comments_count
    FROM users u
    LEFT JOIN photos p 
        ON u.id = p.user_id
    LEFT JOIN likes l 
        ON u.id = l.user_id
    LEFT JOIN comments c 
        ON u.id = c.user_id
    GROUP BY u.id
)

SELECT 
    CASE 
        WHEN posts_count = 0 
         AND likes_count = 0 
         AND comments_count = 0 
        THEN 'Inactive'
        ELSE 'Active'
    END AS user_status,
    COUNT(*) AS user_count
FROM user_engagement
GROUP BY user_status;




/* =======================================================================================================================================================
   Q3. Which hashtags or content topics have the highest engagement rates? How can this information guide content strategy and ad campaigns?
========================================================================================================================================================== */
WITH hashtag_posts AS (
    SELECT 
        pt.tag_id, COUNT(pt.photo_id) AS total_posts
    FROM photo_tags pt
    GROUP BY pt.tag_id
),
likes_per_tag AS (
    SELECT 
        pt.tag_id, COUNT(l.photo_id) AS total_likes
    FROM photo_tags pt
    JOIN likes l ON pt.photo_id = l.photo_id
    GROUP BY pt.tag_id
),
comments_per_tag AS (
    SELECT 
        pt.tag_id, COUNT(c.id) AS total_comments
    FROM photo_tags pt
    JOIN comments c ON pt.photo_id = c.photo_id
    GROUP BY pt.tag_id
),
engagement AS (
    SELECT 
        t.id AS tag_id, t.tag_name,
        COALESCE(hp.total_posts, 0) AS total_posts,
        COALESCE(lp.total_likes, 0) AS likes_received,
        COALESCE(cp.total_comments, 0) AS comments_received,
        COALESCE(lp.total_likes, 0) + COALESCE(cp.total_comments, 0) AS total_engagement,
        CASE 
            WHEN hp.total_posts = 0 THEN 0
            ELSE ROUND((COALESCE(lp.total_likes, 0) + COALESCE(cp.total_comments, 0)) / hp.total_posts, 2)
        END AS engagement_rate
    FROM tags t
    LEFT JOIN hashtag_posts hp ON t.id = hp.tag_id
    LEFT JOIN likes_per_tag lp ON t.id = lp.tag_id
    LEFT JOIN comments_per_tag cp ON t.id = cp.tag_id
)
SELECT *
FROM engagement
WHERE total_posts > 0
ORDER BY engagement_rate DESC
LIMIT 10;




/* =======================================================================================================================================================
   Q5. Based on follower counts and engagement rates, which users would be ideal candidates for influencer marketing campaigns? How would you approach and collaborate with these influencers?
========================================================================================================================================================== */

WITH follower_counts AS (
    SELECT 
        followee_id AS user_id,
        COUNT(*) AS follower_count
    FROM follows
    GROUP BY followee_id
),
post_engagement AS (
    SELECT 
        p.user_id,
        p.id AS photo_id,
        COUNT(l.photo_id) AS likes,
        COUNT(c.id) AS comments
    FROM photos p
    LEFT JOIN likes l ON p.id = l.photo_id
    LEFT JOIN comments c ON p.id = c.photo_id
    GROUP BY p.user_id, p.id
),
engagement_summary AS (
    SELECT 
        user_id,
        COUNT(photo_id) AS total_posts,
        SUM(likes) AS total_likes,
        SUM(comments) AS total_comments,
        ROUND(
            (SUM(likes) + SUM(comments)) / NULLIF(COUNT(photo_id),0),
        2) AS avg_engagement_rate
    FROM post_engagement
    GROUP BY user_id
)
SELECT 
    u.id AS user_id,
    u.username,
    fc.follower_count,
    es.avg_engagement_rate,
    es.total_posts
FROM users u
JOIN follower_counts fc ON u.id = fc.user_id
JOIN engagement_summary es ON u.id = es.user_id
ORDER BY fc.follower_count DESC, es.avg_engagement_rate DESC
LIMIT 10;



/* =======================================================================================================================================================
   Q6. Based on user behavior and engagement data, how would you segment the user base for targeted marketing campaigns or personalized recommendations?
========================================================================================================================================================== */


WITH 
user_posts AS (
  SELECT user_id, COUNT(*) AS total_posts
  FROM photos
  GROUP BY user_id
),
likes_given AS (
  SELECT user_id, COUNT(*) AS total_likes_given
  FROM likes
  GROUP BY user_id
),
comments_given AS (
  SELECT user_id, COUNT(*) AS total_comments_given
  FROM comments
  GROUP BY user_id
),
engagement_received AS (
  SELECT 
    p.user_id,
    COUNT(l.photo_id) AS likes_received,
    COUNT(c.id)      AS comments_received
  FROM photos p
  LEFT JOIN likes l ON p.id = l.photo_id
  LEFT JOIN comments c ON p.id = c.photo_id
  GROUP BY p.user_id
),
user_behavior AS (
  SELECT 
    u.id          AS user_id,
    u.username,
    COALESCE(up.total_posts,0)       AS total_posts,
    COALESCE(lg.total_likes_given,0) AS likes_given,
    COALESCE(cg.total_comments_given,0) AS comments_given,
    COALESCE(er.likes_received,0)    AS likes_received,
    COALESCE(er.comments_received,0) AS comments_received,
    (COALESCE(up.total_posts,0) 
     + COALESCE(lg.total_likes_given,0) 
     + COALESCE(cg.total_comments_given,0)) AS activity_score,
    (COALESCE(er.likes_received,0) + COALESCE(er.comments_received,0)) AS engagement_score
  FROM users u
  LEFT JOIN user_posts up ON u.id = up.user_id
  LEFT JOIN likes_given lg ON u.id = lg.user_id
  LEFT JOIN comments_given cg ON u.id = cg.user_id
  LEFT JOIN engagement_received er ON u.id = er.user_id
)

SELECT
  user_id,
  username,
  CASE
    WHEN activity_score = 0 AND engagement_score = 0 THEN 'Inactive'
    WHEN activity_score BETWEEN 1 AND 5 THEN 'Low Activity'
    WHEN activity_score BETWEEN 6 AND 20 THEN 'Moderate Activity'
    ELSE 'High Activity'
  END AS activity_segment,
  CASE
    WHEN engagement_score = 0 THEN 'No Engagement'
    WHEN engagement_score BETWEEN 1 AND 20 THEN 'Low Engagement'
    WHEN engagement_score BETWEEN 21 AND 100 THEN 'Moderate Engagement'
    ELSE 'High Engagement'
  END AS engagement_segment
FROM user_behavior
ORDER BY activity_segment DESC, engagement_segment DESC;




/* =======================================================================================================================================================
   Q8. How can you use user activity data to identify potential brand ambassadors or advocates who could help promote Instagram's initiatives or events?
========================================================================================================================================================== */

WITH user_activity AS (
    SELECT 
        u.id AS user_id,
        u.username,
        COUNT(DISTINCT p.id) AS posts_count,
        COUNT(DISTINCT l.photo_id) AS likes_given,
        COUNT(DISTINCT c.id) AS comments_written
    FROM users u
    LEFT JOIN photos p 
        ON u.id = p.user_id
    LEFT JOIN likes l 
        ON u.id = l.user_id
    LEFT JOIN comments c 
        ON u.id = c.user_id
    GROUP BY u.id, u.username
),
scored_users AS (
    SELECT
        user_id,
        username,
        posts_count,
        likes_given,
        comments_written,
        (posts_count * 3 
         + likes_given * 1 
         + comments_written * 2) AS activity_score
    FROM user_activity
    WHERE posts_count > 0
)

SELECT *
FROM scored_users
ORDER BY activity_score DESC
LIMIT 10;





/* =======================================================================================================================================================
   Q10. Assuming there's a "User_Interactions" table tracking user engagements, 
        how can you update the "Engagement_Type" column to change all instances of "Like" to "Heart" to align with Instagram's terminology?
========================================================================================================================================================== */

UPDATE User_Interactions
SET Engagement_Type = 'Heart'
WHERE Engagement_Type = 'Like';

















